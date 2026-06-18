import type { Request, Response } from 'express';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../utils/errors.js';
import { sendSuccess } from '../utils/response.js';
import { computeAllScores } from '../utils/strengthScores.js';

// ─── Types ────────────────────────────────────────────────────────────────────

type AttemptResult = 'good_lift' | 'no_lift' | 'not_taken';
type LiftType = 'squat' | 'bench' | 'deadlift';

type AttemptShape = {
  id: string;
  liftType: LiftType;
  attemptNumber: number;
  weightKg: number;
  result: AttemptResult;
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

// Best successful lift for a given lift type (highest weight_kg where result = good_lift).
// Returns null if no good lifts recorded yet.
function bestLift(attempts: AttemptShape[], liftType: LiftType): number | null {
  const goods = attempts
    .filter((a) => a.liftType === liftType && a.result === 'good_lift')
    .map((a) => a.weightKg);
  return goods.length > 0 ? Math.max(...goods) : null;
}

function buildSummary(
  attempts: AttemptShape[],
  bodyweightKg: number | null,
  gender: string | null,
) {
  const squat = bestLift(attempts, 'squat');
  const bench = bestLift(attempts, 'bench');
  const deadlift = bestLift(attempts, 'deadlift');
  const total = squat != null && bench != null && deadlift != null
    ? squat + bench + deadlift
    : null;

  const scores =
    total != null && bodyweightKg != null && gender != null
      ? computeAllScores(total, bodyweightKg, gender)
      : null;

  return { squat, bench, deadlift, total, ...scores };
}

function formatAttempt(a: {
  id: string;
  liftType: string;
  attemptNumber: number;
  weightKg: number;
  result: string;
}): AttemptShape {
  return {
    id: a.id,
    liftType: a.liftType as LiftType,
    attemptNumber: a.attemptNumber,
    weightKg: a.weightKg,
    result: a.result as AttemptResult,
  };
}

// ─── Handlers ────────────────────────────────────────────────────────────────

export const create = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const body = res.locals.validated!.body as {
    name: string;
    federation?: string;
    date: string;
    location?: string;
    weightClassKg?: number;
    bodyweightKg?: number;
    division?: string;
  };

  const comp = await prisma.competition.create({
    data: {
      userId,
      name: body.name,
      federation: body.federation,
      date: new Date(body.date),
      location: body.location,
      weightClassKg: body.weightClassKg,
      bodyweightKg: body.bodyweightKg,
      division: body.division,
      status: 'upcoming',
    },
  });

  sendSuccess(res, {
    id: comp.id,
    name: comp.name,
    federation: comp.federation,
    date: comp.date.toISOString().slice(0, 10),
    location: comp.location,
    weightClassKg: comp.weightClassKg,
    bodyweightKg: comp.bodyweightKg,
    division: comp.division,
    status: comp.status,
    attempts: [],
    squat: null,
    bench: null,
    deadlift: null,
    total: null,
    wilks: null,
    dots: null,
    ipfGl: null,
    createdAt: comp.createdAt.toISOString(),
    updatedAt: comp.updatedAt.toISOString(),
  }, 201);
};

export const list = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;

  const comps = await prisma.competition.findMany({
    where: { userId },
    include: { attempts: true },
    orderBy: { date: 'desc' },
  });

  // Fetch user profile for score computation once — all competitions share the same user.
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { bodyweightKg: true, gender: true },
  });

  sendSuccess(res, comps.map((c) => {
    const attempts = c.attempts.map(formatAttempt);
    // Use competition bodyweight if recorded; fall back to current profile bodyweight.
    const bw = c.bodyweightKg ?? user?.bodyweightKg ?? null;
    const summary = buildSummary(attempts, bw, user?.gender ?? null);
    return {
      id: c.id,
      name: c.name,
      federation: c.federation,
      date: c.date.toISOString().slice(0, 10),
      location: c.location,
      weightClassKg: c.weightClassKg,
      bodyweightKg: c.bodyweightKg,
      division: c.division,
      status: c.status,
      attempts,
      ...summary,
      createdAt: c.createdAt.toISOString(),
      updatedAt: c.updatedAt.toISOString(),
    };
  }));
};

export const getOne = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { id } = res.locals.validated!.params as { id: string };

  const comp = await prisma.competition.findFirst({
    where: { id, userId },
    include: { attempts: { orderBy: [{ liftType: 'asc' }, { attemptNumber: 'asc' }] } },
  });
  if (!comp) throw new AppError(404, 'Competition not found');

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { bodyweightKg: true, gender: true },
  });

  const attempts = comp.attempts.map(formatAttempt);
  const bw = comp.bodyweightKg ?? user?.bodyweightKg ?? null;
  const summary = buildSummary(attempts, bw, user?.gender ?? null);

  sendSuccess(res, {
    id: comp.id,
    name: comp.name,
    federation: comp.federation,
    date: comp.date.toISOString().slice(0, 10),
    location: comp.location,
    weightClassKg: comp.weightClassKg,
    bodyweightKg: comp.bodyweightKg,
    division: comp.division,
    status: comp.status,
    attempts,
    ...summary,
    createdAt: comp.createdAt.toISOString(),
    updatedAt: comp.updatedAt.toISOString(),
  });
};

export const logAttempt = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { id } = res.locals.validated!.params as { id: string };
  const body = res.locals.validated!.body as {
    liftType: LiftType;
    attemptNumber: 1 | 2 | 3;
    weightKg: number;
    result: AttemptResult;
  };

  const comp = await prisma.competition.findFirst({ where: { id, userId } });
  if (!comp) throw new AppError(404, 'Competition not found');

  // Upsert so re-submitting the same (liftType, attemptNumber) updates the result
  // rather than erroring — refs the unique index on (competition_id, lift_type, attempt_number).
  const attempt = await prisma.competitionAttempt.upsert({
    where: {
      competitionId_liftType_attemptNumber: {
        competitionId: id,
        liftType: body.liftType,
        attemptNumber: body.attemptNumber,
      },
    },
    create: {
      competitionId: id,
      liftType: body.liftType,
      attemptNumber: body.attemptNumber,
      weightKg: body.weightKg,
      result: body.result,
    },
    update: { weightKg: body.weightKg, result: body.result },
  });

  // Auto-complete when all 9 slots are filled (any result, including not_taken for passed attempts).
  const totalAttempts = await prisma.competitionAttempt.count({
    where: { competitionId: id },
  });
  if (totalAttempts >= 9 && comp.status === 'upcoming') {
    await prisma.competition.update({
      where: { id },
      data: { status: 'completed' },
    });
  }

  sendSuccess(res, formatAttempt(attempt));
};

export const update = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { id } = res.locals.validated!.params as { id: string };
  const body = res.locals.validated!.body as {
    name?: string;
    federation?: string;
    date?: string;
    location?: string;
    weightClassKg?: number;
    bodyweightKg?: number;
    division?: string;
    status?: 'upcoming' | 'completed';
  };

  const comp = await prisma.competition.findFirst({ where: { id, userId } });
  if (!comp) throw new AppError(404, 'Competition not found');

  const updated = await prisma.competition.update({
    where: { id },
    data: {
      ...(body.name !== undefined && { name: body.name }),
      ...(body.federation !== undefined && { federation: body.federation }),
      ...(body.date !== undefined && { date: new Date(body.date) }),
      ...(body.location !== undefined && { location: body.location }),
      ...(body.weightClassKg !== undefined && { weightClassKg: body.weightClassKg }),
      ...(body.bodyweightKg !== undefined && { bodyweightKg: body.bodyweightKg }),
      ...(body.division !== undefined && { division: body.division }),
      ...(body.status !== undefined && { status: body.status }),
    },
  });

  sendSuccess(res, {
    id: updated.id,
    name: updated.name,
    federation: updated.federation,
    date: updated.date.toISOString().slice(0, 10),
    location: updated.location,
    weightClassKg: updated.weightClassKg,
    bodyweightKg: updated.bodyweightKg,
    division: updated.division,
    status: updated.status,
    updatedAt: updated.updatedAt.toISOString(),
  });
};
