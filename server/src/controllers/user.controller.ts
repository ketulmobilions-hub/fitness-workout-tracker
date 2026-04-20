import type { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { OAuth2Client } from 'google-auth-library';
import appleSignin from 'apple-signin-auth';
import { Prisma } from '../generated/prisma/client.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../utils/errors.js';
import { sendSuccess } from '../utils/response.js';
import { env } from '../utils/env.js';

// Separate instance from auth.controller — both share the underlying JWKS cache from
// the google-auth-library internals, so there is no extra network overhead.
const googleClient = new OAuth2Client(env.GOOGLE_CLIENT_ID);

type UserRow = {
  id: string;
  email: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  bio: string | null;
  authProvider: string;
  isGuest: boolean;
  preferences: Prisma.JsonValue;
  createdAt: Date;
  updatedAt: Date;
};

function mapUser(user: UserRow): Record<string, unknown> {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    avatarUrl: user.avatarUrl,
    bio: user.bio,
    authProvider: user.authProvider,
    isGuest: user.isGuest,
    preferences: user.preferences ?? {},
    createdAt: user.createdAt.toISOString(),
    updatedAt: user.updatedAt.toISOString(),
  };
}

const USER_SELECT = {
  id: true,
  email: true,
  displayName: true,
  avatarUrl: true,
  bio: true,
  authProvider: true,
  isGuest: true,
  preferences: true,
  createdAt: true,
  updatedAt: true,
} as const;

export const getProfile = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;

  const user = await prisma.user.findUnique({ where: { id: userId }, select: USER_SELECT });
  if (!user) throw new AppError(404, 'User not found');

  sendSuccess(res, { user: mapUser(user) });
};

export const updateProfile = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const body = res.locals.validated!.body as {
    displayName?: string | null;
    avatarUrl?: string | null;
    bio?: string | null;
  };

  try {
    const user = await prisma.user.update({
      where: { id: userId },
      data: {
        ...(body.displayName !== undefined && { displayName: body.displayName }),
        ...(body.avatarUrl !== undefined && { avatarUrl: body.avatarUrl }),
        ...(body.bio !== undefined && { bio: body.bio }),
      },
      select: USER_SELECT,
    });
    sendSuccess(res, { user: mapUser(user) });
  } catch (err: unknown) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      throw new AppError(404, 'User not found');
    }
    throw err;
  }
};

export const updatePreferences = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const body = res.locals.validated!.body as {
    units?: 'metric' | 'imperial';
    theme?: 'light' | 'dark' | 'system';
    notifications?: {
      workoutReminders?: boolean;
      streakAlerts?: boolean;
      weeklyReport?: boolean;
    };
  };

  // Atomic merge using PostgreSQL's jsonb || operator — no transaction or
  // read-modify-write needed. Two concurrent requests each apply their own
  // key(s) without clobbering the other's keys.
  const rows = await prisma.$queryRaw<Array<{ preferences: unknown }>>`
    UPDATE users
    SET preferences = COALESCE(preferences, '{}'::jsonb) || ${JSON.stringify(body)}::jsonb,
        updated_at = NOW()
    WHERE id = ${userId}::uuid
    RETURNING preferences
  `;

  if (rows.length === 0) throw new AppError(404, 'User not found');

  sendSuccess(res, { preferences: rows[0].preferences });
};

export const getStats = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;

  const [user, totalWorkouts, volumeRows, streak] = await Promise.all([
    prisma.user.findUnique({ where: { id: userId }, select: { createdAt: true } }),
    prisma.workoutSession.count({ where: { userId, status: 'completed' } }),
    prisma.$queryRaw<Array<{ total_volume: string }>>`
      SELECT COALESCE(SUM(sl.weight_kg * sl.reps), 0) AS total_volume
      FROM workout_sessions ws
      JOIN exercise_logs el ON el.session_id = ws.id
      JOIN set_logs sl ON sl.exercise_log_id = el.id
      WHERE ws.user_id = ${userId}::uuid
        AND ws.status = 'completed'
        AND sl.is_warmup = false
        AND sl.weight_kg IS NOT NULL
        AND sl.reps IS NOT NULL
    `,
    prisma.streak.findUnique({
      where: { userId },
      select: { currentStreak: true, longestStreak: true, lastWorkoutDate: true },
    }),
  ]);

  if (!user) throw new AppError(404, 'User not found');

  // COALESCE guarantees exactly one row — this guards against unexpected schema changes
  // that rename the column, which would cause total_volume to be undefined and
  // Number(undefined) to silently produce NaN serialized as null in JSON.
  if (volumeRows.length === 0 || volumeRows[0].total_volume === undefined) {
    throw new AppError(500, 'Unexpected volume query result');
  }

  sendSuccess(res, {
    totalWorkouts,
    totalVolumeKg: Number(volumeRows[0].total_volume),
    currentStreak: streak?.currentStreak ?? 0,
    longestStreak: streak?.longestStreak ?? 0,
    memberSince: user.createdAt.toISOString(),
    lastWorkoutDate: streak?.lastWorkoutDate
      ? (streak.lastWorkoutDate as Date).toISOString().slice(0, 10)
      : null,
  });
};

export const deleteAccount = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const body = res.locals.validated!.body as {
    password?: string;
    idToken?: string;
    identityToken?: string;
    confirmPhrase: 'DELETE MY ACCOUNT';
  };

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { authProvider: true, passwordHash: true },
  });
  if (!user) throw new AppError(404, 'User not found');

  if (user.authProvider === 'email' && user.passwordHash) {
    if (!body.password) {
      throw new AppError(400, 'Password confirmation is required for email accounts');
    }
    const valid = await bcrypt.compare(body.password, user.passwordHash);
    if (!valid) throw new AppError(401, 'Incorrect password');
  } else if (user.authProvider === 'google') {
    if (!body.idToken) {
      throw new AppError(400, 'Google ID token is required to delete a Google account');
    }
    try {
      await googleClient.verifyIdToken({ idToken: body.idToken, audience: env.GOOGLE_CLIENT_ID });
    } catch {
      throw new AppError(401, 'Invalid Google ID token');
    }
  } else if (user.authProvider === 'apple') {
    if (!body.identityToken) {
      throw new AppError(400, 'Apple identity token is required to delete an Apple account');
    }
    try {
      await appleSignin.verifyIdToken(body.identityToken, {
        audience: env.APPLE_APP_BUNDLE_ID,
        ignoreExpiration: false,
      });
    } catch {
      throw new AppError(401, 'Invalid Apple identity token');
    }
  }

  await prisma.user.delete({ where: { id: userId } });

  sendSuccess(res, { message: 'Account deleted successfully' });
};
