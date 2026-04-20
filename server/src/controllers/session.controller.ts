import type { Request, Response } from 'express';
import { Prisma } from '../generated/prisma/client.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../utils/errors.js';
import { sendSuccess } from '../utils/response.js';

// ─── Types ────────────────────────────────────────────────────────────────────

type SessionWithLogs = Prisma.WorkoutSessionGetPayload<{
  include: {
    exerciseLogs: {
      include: {
        exercise: true;
        setLogs: { orderBy: { setNumber: 'asc' } };
      };
      orderBy: { sortOrder: 'asc' };
    };
  };
}>;

type ExerciseLogWithSets = SessionWithLogs['exerciseLogs'][number];

type MappedSetLog = {
  id: string;
  setNumber: number;
  reps: number | null;
  weightKg: number | null;
  durationSec: number | null;
  distanceM: number | null;
  paceSecPerKm: number | null;
  heartRate: number | null;
  rpe: number | null;
  tempo: string | null;
  isWarmup: boolean;
  completedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

type MappedExerciseLog = {
  id: string;
  exerciseId: string;
  exerciseName: string;
  exerciseType: string;
  sortOrder: number;
  notes: string | null;
  sets: MappedSetLog[];
};

type MappedSessionDetail = {
  id: string;
  planId: string | null;
  planDayId: string | null;
  status: string;
  startedAt: string;
  completedAt: string | null;
  durationSec: number | null;
  notes: string | null;
  exercises: MappedExerciseLog[];
  createdAt: string;
  updatedAt: string;
};

type MappedSessionSummary = {
  id: string;
  planId: string | null;
  planDayId: string | null;
  status: string;
  startedAt: string;
  completedAt: string | null;
  durationSec: number | null;
  notes: string | null;
  exerciseCount: number;
  createdAt: string;
  updatedAt: string;
};

type MappedNewPR = {
  exerciseId: string;
  exerciseName: string;
  recordType: string;
  value: number;
  achievedAt: string;
};

type DecodedSessionCursor = { id: string; startedAt: string };

// ─── Helpers ──────────────────────────────────────────────────────────────────

const sessionDetailInclude = {
  exerciseLogs: {
    orderBy: { sortOrder: 'asc' as const },
    include: {
      exercise: true,
      setLogs: { orderBy: { setNumber: 'asc' as const } },
    },
  },
} satisfies Prisma.WorkoutSessionInclude;

function mapSetLog(s: ExerciseLogWithSets['setLogs'][number]): MappedSetLog {
  return {
    id: s.id,
    setNumber: s.setNumber,
    reps: s.reps,
    weightKg: s.weightKg,
    durationSec: s.durationSec,
    distanceM: s.distanceM,
    paceSecPerKm: s.paceSecPerKm,
    heartRate: s.heartRate,
    rpe: s.rpe,
    tempo: s.tempo,
    isWarmup: s.isWarmup,
    completedAt: s.completedAt?.toISOString() ?? null,
    createdAt: s.createdAt.toISOString(),
    updatedAt: s.updatedAt.toISOString(),
  };
}

function mapExerciseLog(log: ExerciseLogWithSets): MappedExerciseLog {
  return {
    id: log.id,
    exerciseId: log.exercise.id,
    exerciseName: log.exercise.name,
    exerciseType: log.exercise.exerciseType,
    sortOrder: log.sortOrder,
    notes: log.notes,
    sets: log.setLogs.map(mapSetLog),
  };
}

function mapSessionDetail(session: SessionWithLogs): MappedSessionDetail {
  return {
    id: session.id,
    planId: session.planId,
    planDayId: session.planDayId,
    status: session.status,
    startedAt: session.startedAt.toISOString(),
    completedAt: session.completedAt?.toISOString() ?? null,
    durationSec: session.durationSec,
    notes: session.notes,
    exercises: session.exerciseLogs.map(mapExerciseLog),
    createdAt: session.createdAt.toISOString(),
    updatedAt: session.updatedAt.toISOString(),
  };
}

function encodeSessionCursor(session: { id: string; startedAt: Date }): string {
  const payload: DecodedSessionCursor = { id: session.id, startedAt: session.startedAt.toISOString() };
  return Buffer.from(JSON.stringify(payload)).toString('base64url');
}

function decodeSessionCursor(cursor: string): DecodedSessionCursor {
  try {
    const raw = Buffer.from(cursor, 'base64url').toString('utf8');
    const parsed = JSON.parse(raw) as unknown;
    if (
      typeof parsed === 'object' &&
      parsed !== null &&
      Object.keys(parsed as object).length === 2 &&
      'id' in parsed &&
      'startedAt' in parsed &&
      typeof (parsed as Record<string, unknown>).id === 'string' &&
      typeof (parsed as Record<string, unknown>).startedAt === 'string'
    ) {
      return parsed as DecodedSessionCursor;
    }
  } catch {
    // fall through
  }
  throw new AppError(400, 'Invalid or expired pagination cursor');
}

// Derives the local calendar date (YYYY-MM-DD) from an ISO datetime string.
// If the string carries a UTC offset (e.g. "-08:00"), the offset is applied so
// that a workout logged at 23:00 local time counts for the correct calendar day
// rather than rolling into the next UTC day.
function localDateFromISO(isoStr: string): string {
  const offsetMatch = isoStr.match(/([+-])(\d{2}):(\d{2})$/);
  if (!offsetMatch) return new Date(isoStr).toISOString().slice(0, 10); // Z or no offset → UTC
  const sign = offsetMatch[1] === '+' ? 1 : -1;
  const offsetMs = sign * (parseInt(offsetMatch[2]) * 60 + parseInt(offsetMatch[3])) * 60 * 1000;
  return new Date(new Date(isoStr).getTime() + offsetMs).toISOString().slice(0, 10);
}

// Computes candidate PR values from the sets of a single exercise log.
// Warmup sets are excluded from max_volume to avoid inflating volume records
// with intentionally sub-maximal data.
function computePRCandidates(
  setLogs: ExerciseLogWithSets['setLogs'],
): Partial<Record<'max_weight' | 'max_reps' | 'max_volume' | 'best_pace', number>> {
  const candidates: Partial<Record<'max_weight' | 'max_reps' | 'max_volume' | 'best_pace', number>> = {};

  let maxWeight: number | null = null;
  let maxReps: number | null = null;
  let totalVolume = 0;
  let hasVolume = false;
  let bestPace: number | null = null;

  for (const s of setLogs) {
    if (s.weightKg !== null) {
      maxWeight = maxWeight === null ? s.weightKg : Math.max(maxWeight, s.weightKg);
    }
    if (s.reps !== null) {
      maxReps = maxReps === null ? s.reps : Math.max(maxReps, s.reps);
    }
    // Exclude warmup sets from volume — warmups are sub-maximal by design.
    if (!s.isWarmup && s.weightKg !== null && s.reps !== null) {
      totalVolume += s.weightKg * s.reps;
      hasVolume = true;
    }
    if (s.paceSecPerKm !== null) {
      bestPace = bestPace === null ? s.paceSecPerKm : Math.min(bestPace, s.paceSecPerKm);
    }
  }

  if (maxWeight !== null && maxWeight > 0) candidates.max_weight = maxWeight;
  if (maxReps !== null && maxReps > 0) candidates.max_reps = maxReps;
  if (hasVolume && totalVolume > 0) candidates.max_volume = totalVolume;
  if (bestPace !== null && bestPace > 0) candidates.best_pace = bestPace;

  return candidates;
}

// ─── Handlers ─────────────────────────────────────────────────────────────────

export const startSession = async (_req: Request, res: Response): Promise<void> => {
  const body = res.locals.validated!.body as {
    planId?: string;
    planDayId?: string;
    startedAt?: string;
  };
  const { userId } = res.locals.auth!;

  const session = await prisma.$transaction(async (tx) => {
    if (body.planId) {
      const plan = await tx.workoutPlan.findFirst({
        where: { id: body.planId, userId, deletedAt: null },
        select: { id: true },
      });
      if (!plan) throw new AppError(404, 'Workout plan not found');
    }

    if (body.planDayId) {
      // Filter through plan ownership to prevent attaching to a soft-deleted
      // or foreign plan's day in the window between the plan check above and this query.
      const planDay = await tx.planDay.findFirst({
        where: { id: body.planDayId, planId: body.planId, plan: { userId, deletedAt: null } },
        select: { id: true },
      });
      if (!planDay) throw new AppError(404, 'Plan day not found');
    }

    return tx.workoutSession.create({
      data: {
        userId,
        planId: body.planId ?? null,
        planDayId: body.planDayId ?? null,
        startedAt: body.startedAt ? new Date(body.startedAt) : new Date(),
        status: 'in_progress',
      },
      include: sessionDetailInclude,
    });
  });

  sendSuccess(res, { session: mapSessionDetail(session) }, 201);
};

export const listSessions = async (_req: Request, res: Response): Promise<void> => {
  const { cursor, limit, from, to, status } = res.locals.validated!.query as {
    cursor?: string;
    limit: number;
    from?: string;
    to?: string;
    status?: string;
  };
  const { userId } = res.locals.auth!;

  const where: Prisma.WorkoutSessionWhereInput = { userId };

  if (from || to) {
    where.startedAt = {
      ...(from ? { gte: new Date(from) } : {}),
      ...(to ? { lte: new Date(to) } : {}),
    };
  }

  if (status) {
    where.status = status as 'in_progress' | 'completed' | 'abandoned';
  }

  if (cursor) {
    const decoded = decodeSessionCursor(cursor);
    const cursorDate = new Date(decoded.startedAt);
    // Keyset for ORDER BY startedAt DESC, id DESC:
    // next page = rows with (startedAt < cursor) OR (startedAt = cursor AND id < cursorId)
    where.OR = [
      { startedAt: { lt: cursorDate } },
      { AND: [{ startedAt: cursorDate }, { id: { lt: decoded.id } }] },
    ];
  }

  const rows = await prisma.workoutSession.findMany({
    where,
    orderBy: [{ startedAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    include: { _count: { select: { exerciseLogs: true } } },
  });

  const hasMore = rows.length > limit;
  const data = hasMore ? rows.slice(0, limit) : rows;
  const nextCursor = hasMore ? encodeSessionCursor(data.at(-1)!) : null;

  const sessions: MappedSessionSummary[] = data.map((s) => ({
    id: s.id,
    planId: s.planId,
    planDayId: s.planDayId,
    status: s.status,
    startedAt: s.startedAt.toISOString(),
    completedAt: s.completedAt?.toISOString() ?? null,
    durationSec: s.durationSec,
    notes: s.notes,
    exerciseCount: s._count.exerciseLogs,
    createdAt: s.createdAt.toISOString(),
    updatedAt: s.updatedAt.toISOString(),
  }));

  sendSuccess(res, {
    sessions,
    pagination: { next_cursor: nextCursor, has_more: hasMore, limit },
  });
};

export const getSession = async (_req: Request, res: Response): Promise<void> => {
  const { id } = res.locals.validated!.params as { id: string };
  const { userId } = res.locals.auth!;

  const session = await prisma.workoutSession.findFirst({
    where: { id, userId },
    include: sessionDetailInclude,
  });

  if (!session) throw new AppError(404, 'Workout session not found');

  sendSuccess(res, { session: mapSessionDetail(session) });
};

export const updateSession = async (_req: Request, res: Response): Promise<void> => {
  const { id } = res.locals.validated!.params as { id: string };
  const body = res.locals.validated!.body as {
    notes?: string | null;
    status?: 'abandoned';
  };
  const { userId } = res.locals.auth!;

  // Merge the ownership + status guard into the WHERE clause so the check and
  // the write are atomic — no TOCTOU window for a concurrent completeSession call.
  try {
    const updated = await prisma.workoutSession.update({
      where: { id, userId, status: 'in_progress' },
      data: {
        ...('notes' in body && { notes: body.notes }),
        ...(body.status !== undefined && { status: body.status }),
      },
      include: sessionDetailInclude,
    });
    sendSuccess(res, { session: mapSessionDetail(updated) });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      // P2025 fires for both "session not found" and "session not in_progress".
      // Distinguish them so the client gets the right error code.
      const exists = await prisma.workoutSession.findFirst({ where: { id, userId }, select: { id: true } });
      if (!exists) throw new AppError(404, 'Workout session not found');
      throw new AppError(422, 'Cannot update a session that is not in progress');
    }
    throw err;
  }
};

export const logSet = async (_req: Request, res: Response): Promise<void> => {
  const { id: sessionId } = res.locals.validated!.params as { id: string };
  const body = res.locals.validated!.body as {
    exerciseId: string;
    setNumber: number;
    reps?: number;
    weightKg?: number;
    durationSec?: number;
    distanceM?: number;
    paceSecPerKm?: number;
    heartRate?: number;
    rpe?: number;
    tempo?: string;
    isWarmup?: boolean;
    completedAt?: string;
  };
  const { userId } = res.locals.auth!;

  const setLog = await prisma.$transaction(async (tx) => {
    // Verify session ownership and that it is still in progress.
    const session = await tx.workoutSession.findFirst({
      where: { id: sessionId, userId },
      select: { id: true, status: true },
    });
    if (!session) throw new AppError(404, 'Workout session not found');
    if (session.status !== 'in_progress') {
      throw new AppError(422, 'Cannot log sets on a session that is not in progress');
    }

    // Verify exercise exists.
    const exercise = await tx.exercise.findUnique({
      where: { id: body.exerciseId },
      select: { id: true },
    });
    if (!exercise) throw new AppError(404, 'Exercise not found');

    // Find or create the ExerciseLog for this (session, exercise) pair.
    let exerciseLog = await tx.exerciseLog.findFirst({
      where: { sessionId, exerciseId: body.exerciseId },
      select: { id: true },
    });

    if (!exerciseLog) {
      // Compute next sortOrder (max + 1) atomically within the transaction.
      const maxOrder = await tx.exerciseLog.aggregate({
        where: { sessionId },
        _max: { sortOrder: true },
      });
      const nextSortOrder = (maxOrder._max.sortOrder ?? -1) + 1;

      exerciseLog = await tx.exerciseLog.create({
        data: {
          sessionId,
          exerciseId: body.exerciseId,
          sortOrder: nextSortOrder,
        },
        select: { id: true },
      });
    }

    return tx.setLog.create({
      data: {
        exerciseLogId: exerciseLog.id,
        setNumber: body.setNumber,
        reps: body.reps ?? null,
        weightKg: body.weightKg ?? null,
        durationSec: body.durationSec ?? null,
        distanceM: body.distanceM ?? null,
        paceSecPerKm: body.paceSecPerKm ?? null,
        heartRate: body.heartRate ?? null,
        rpe: body.rpe ?? null,
        tempo: body.tempo ?? null,
        isWarmup: body.isWarmup ?? false,
        completedAt: body.completedAt ? new Date(body.completedAt) : null,
      },
    });
  });

  sendSuccess(
    res,
    {
      set: {
        id: setLog.id,
        setNumber: setLog.setNumber,
        reps: setLog.reps,
        weightKg: setLog.weightKg,
        durationSec: setLog.durationSec,
        distanceM: setLog.distanceM,
        paceSecPerKm: setLog.paceSecPerKm,
        heartRate: setLog.heartRate,
        rpe: setLog.rpe,
        tempo: setLog.tempo,
        isWarmup: setLog.isWarmup,
        completedAt: setLog.completedAt?.toISOString() ?? null,
        createdAt: setLog.createdAt.toISOString(),
        updatedAt: setLog.updatedAt.toISOString(),
      },
    },
    201,
  );
};

export const updateSet = async (_req: Request, res: Response): Promise<void> => {
  const { id: sessionId, setId } = res.locals.validated!.params as { id: string; setId: string };
  const body = res.locals.validated!.body as {
    reps?: number | null;
    weightKg?: number | null;
    durationSec?: number | null;
    distanceM?: number | null;
    paceSecPerKm?: number | null;
    heartRate?: number | null;
    rpe?: number | null;
    tempo?: string | null;
    isWarmup?: boolean;
    completedAt?: string | null;
  };
  const { userId } = res.locals.auth!;

  // Verify session ownership and that it is still in progress.
  // Sets on completed/abandoned sessions are immutable — editing them would
  // corrupt the source data behind already-computed personal records.
  const session = await prisma.workoutSession.findFirst({
    where: { id: sessionId, userId },
    select: { id: true, status: true },
  });
  if (!session) throw new AppError(404, 'Workout session not found');
  if (session.status !== 'in_progress') {
    throw new AppError(422, 'Cannot edit sets on a session that is not in progress');
  }

  // Verify set belongs to this session via the exerciseLog chain.
  const setLog = await prisma.setLog.findFirst({
    where: { id: setId, exerciseLog: { sessionId } },
    select: { id: true },
  });
  if (!setLog) throw new AppError(404, 'Set not found');

  try {
    const updated = await prisma.setLog.update({
      where: { id: setId },
      data: {
        ...('reps' in body && { reps: body.reps }),
        ...('weightKg' in body && { weightKg: body.weightKg }),
        ...('durationSec' in body && { durationSec: body.durationSec }),
        ...('distanceM' in body && { distanceM: body.distanceM }),
        ...('paceSecPerKm' in body && { paceSecPerKm: body.paceSecPerKm }),
        ...('heartRate' in body && { heartRate: body.heartRate }),
        ...('rpe' in body && { rpe: body.rpe }),
        ...('tempo' in body && { tempo: body.tempo }),
        ...(body.isWarmup !== undefined && { isWarmup: body.isWarmup }),
        ...('completedAt' in body && {
          completedAt: body.completedAt ? new Date(body.completedAt) : null,
        }),
      },
    });

    sendSuccess(res, {
      set: {
        id: updated.id,
        setNumber: updated.setNumber,
        reps: updated.reps,
        weightKg: updated.weightKg,
        durationSec: updated.durationSec,
        distanceM: updated.distanceM,
        paceSecPerKm: updated.paceSecPerKm,
        heartRate: updated.heartRate,
        rpe: updated.rpe,
        tempo: updated.tempo,
        isWarmup: updated.isWarmup,
        completedAt: updated.completedAt?.toISOString() ?? null,
        createdAt: updated.createdAt.toISOString(),
        updatedAt: updated.updatedAt.toISOString(),
      },
    });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      throw new AppError(404, 'Set not found');
    }
    throw err;
  }
};

export const deleteSet = async (_req: Request, res: Response): Promise<void> => {
  const { id: sessionId, setId } = res.locals.validated!.params as { id: string; setId: string };
  const { userId } = res.locals.auth!;

  // Verify session ownership and in-progress status.
  // Deleting sets from a completed session would orphan the personal records
  // computed from those sets during session completion.
  const session = await prisma.workoutSession.findFirst({
    where: { id: sessionId, userId },
    select: { id: true, status: true },
  });
  if (!session) throw new AppError(404, 'Workout session not found');
  if (session.status !== 'in_progress') {
    throw new AppError(422, 'Cannot delete sets from a session that is not in progress');
  }

  // Verify set belongs to this session.
  const setLog = await prisma.setLog.findFirst({
    where: { id: setId, exerciseLog: { sessionId } },
    select: { id: true },
  });
  if (!setLog) throw new AppError(404, 'Set not found');

  try {
    await prisma.setLog.delete({ where: { id: setId } });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      // Concurrent delete — treat as success since the resource is already gone.
      res.status(204).end();
      return;
    }
    throw err;
  }

  res.status(204).end();
};

export const completeSession = async (_req: Request, res: Response): Promise<void> => {
  const { id: sessionId } = res.locals.validated!.params as { id: string };
  const body = res.locals.validated!.body as {
    completedAt?: string;
    durationSec?: number;
    notes?: string | null;
  };
  const { userId } = res.locals.auth!;

  // Use the client-supplied completedAt (with its UTC offset) to derive the
  // correct local calendar date for streak calculations. Falls back to server
  // UTC time when completedAt is not provided.
  const completedAtStr = body.completedAt ?? new Date().toISOString();
  const completedAt = new Date(completedAtStr);
  const today = localDateFromISO(completedAtStr);

  const { session, newPersonalRecords } = await prisma.$transaction(async (tx) => {
    // Verify session ownership and in-progress status.
    const existing = await tx.workoutSession.findFirst({
      where: { id: sessionId, userId },
      select: { id: true, status: true, startedAt: true },
    });
    if (!existing) throw new AppError(404, 'Workout session not found');
    if (existing.status !== 'in_progress') {
      throw new AppError(422, 'Session is not in progress');
    }
    // completedAt must not precede the session start — guards against corrupt duration data.
    if (completedAt < existing.startedAt) {
      throw new AppError(422, 'completedAt cannot be before the session start time');
    }

    // 1. Complete the session.
    const completed = await tx.workoutSession.update({
      where: { id: sessionId },
      data: {
        status: 'completed',
        completedAt,
        ...(body.durationSec !== undefined && { durationSec: body.durationSec }),
        ...('notes' in body && { notes: body.notes }),
      },
      include: sessionDetailInclude,
    });

    // 2. Streak update — only for sessions linked to a plan day.
    // Free workouts (no planDayId) do not affect the streak because the daily job
    // checks plan schedule to determine missed vs rest days; free sessions are
    // outside that system.
    if (completed.planDayId) {
      // Issue 8: explicit UTC midnight construction — `new Date('YYYY-MM-DD')` is
      // spec-defined as UTC, but being explicit avoids surprising future readers.
      const todayDate = new Date(`${today}T00:00:00Z`);

      // Issue 7: idempotency guard for multiple planned sessions on the same day.
      // If today is already 'completed' in streak_history, a prior planned session
      // already incremented the counter — don't re-increment.
      const todayHistory = await tx.streakHistory.findUnique({
        where: { userId_date: { userId, date: todayDate } },
        select: { status: true },
      });

      if (todayHistory?.status !== 'completed') {
        // Find the most recent streak_history entry that is not a rest day.
        // Rest days are transparent to streak counting — they bridge workout days
        // in plans that don't schedule every calendar day.
        const lastNonRestEntry = await tx.streakHistory.findFirst({
          where: { userId, date: { lt: todayDate }, status: { not: 'rest_day' } },
          orderBy: { date: 'desc' },
          select: { status: true },
        });

        const streak = await tx.streak.findUnique({
          where: { userId },
          select: { currentStreak: true, longestStreak: true },
        });

        // Extend streak if the last non-rest day was completed; otherwise start fresh.
        const newCurrent =
          lastNonRestEntry?.status === 'completed' ? (streak?.currentStreak ?? 0) + 1 : 1;
        const newLongest = Math.max(newCurrent, streak?.longestStreak ?? 0);

        await tx.streak.upsert({
          where: { userId },
          create: { userId, currentStreak: newCurrent, longestStreak: newLongest, lastWorkoutDate: todayDate },
          update: { currentStreak: newCurrent, longestStreak: newLongest, lastWorkoutDate: todayDate },
        });

        await tx.streakHistory.upsert({
          where: { userId_date: { userId, date: todayDate } },
          create: { userId, date: todayDate, status: 'completed' },
          update: { status: 'completed' },
        });
      }
    }

    // 3. PR detection — batch-load all current PRs for exercises in this session,
    // then evaluate candidates in memory to avoid N+1 queries inside the transaction.
    const exerciseIds = completed.exerciseLogs.map((log) => log.exerciseId);
    const existingPRs =
      exerciseIds.length > 0
        ? await tx.personalRecord.findMany({
            where: { userId, exerciseId: { in: exerciseIds } },
            select: { exerciseId: true, recordType: true, value: true },
          })
        : [];

    // Build a lookup: exerciseId → recordType → current best value
    const prBestMap = new Map<string, Map<string, number>>();
    for (const pr of existingPRs) {
      if (!prBestMap.has(pr.exerciseId)) prBestMap.set(pr.exerciseId, new Map());
      const typeMap = prBestMap.get(pr.exerciseId)!;
      const current = typeMap.get(pr.recordType);
      const isPace = pr.recordType === 'best_pace';
      if (current === undefined || (isPace ? pr.value < current : pr.value > current)) {
        typeMap.set(pr.recordType, pr.value);
      }
    }

    const newPRs: MappedNewPR[] = [];

    for (const exLog of completed.exerciseLogs) {
      if (exLog.setLogs.length === 0) continue;

      const candidates = computePRCandidates(exLog.setLogs);

      for (const [recordTypeKey, candidateValue] of Object.entries(candidates) as Array<
        ['max_weight' | 'max_reps' | 'max_volume' | 'best_pace', number]
      >) {
        const isPaceRecord = recordTypeKey === 'best_pace';
        const existingBest = prBestMap.get(exLog.exerciseId)?.get(recordTypeKey);

        const isBetter =
          existingBest === undefined ||
          (isPaceRecord ? candidateValue < existingBest : candidateValue > existingBest);

        if (isBetter) {
          await tx.personalRecord.create({
            data: {
              userId,
              exerciseId: exLog.exerciseId,
              recordType: recordTypeKey,
              value: candidateValue,
              achievedAt: completedAt,
              sessionId,
            },
          });
          // Update the in-memory map so later exercises in the same session
          // compare against the PR just set (relevant if the same exercise
          // appears more than once).
          if (!prBestMap.has(exLog.exerciseId)) prBestMap.set(exLog.exerciseId, new Map());
          prBestMap.get(exLog.exerciseId)!.set(recordTypeKey, candidateValue);

          newPRs.push({
            exerciseId: exLog.exerciseId,
            exerciseName: exLog.exercise.name,
            recordType: recordTypeKey,
            value: candidateValue,
            achievedAt: completedAt.toISOString(),
          });
        }
      }
    }

    return { session: completed, newPersonalRecords: newPRs };
  });

  sendSuccess(res, { session: mapSessionDetail(session), newPersonalRecords });
};
