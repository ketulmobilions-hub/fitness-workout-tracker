import type { Request, Response } from 'express';
import { Prisma } from '../generated/prisma/client.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../utils/errors.js';
import { sendSuccess } from '../utils/response.js';

// ─── Types ────────────────────────────────────────────────────────────────────

type PlanWithDays = Prisma.WorkoutPlanGetPayload<{
  include: {
    planDays: {
      include: {
        exercises: { include: { exercise: true }; orderBy: { sortOrder: 'asc' } };
      };
      orderBy: { sortOrder: 'asc' };
    };
  };
}>;

type PlanDayWithExercises = PlanWithDays['planDays'][number];

// Standalone type for a single exercise entry (used by add/update/reorder responses).
// Matches the payload of create/update/findMany with { include: { exercise: true } }.
type ExerciseEntry = Prisma.PlanDayExerciseGetPayload<{ include: { exercise: true } }>;

type MappedPlanDayExercise = {
  id: string;
  exerciseId: string;
  exerciseName: string;
  exerciseType: string;
  sortOrder: number;
  targetSets: number | null;
  targetReps: string | null;
  targetDurationSec: number | null;
  targetDistanceM: number | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
};

type MappedPlanDay = {
  id: string;
  dayOfWeek: number;
  weekNumber: number | null;
  name: string | null;
  sortOrder: number;
  exercises: MappedPlanDayExercise[];
};

type MappedPlanSummary = {
  id: string;
  name: string;
  description: string | null;
  isActive: boolean;
  scheduleType: string;
  weeksCount: number | null;
  createdAt: string;
  updatedAt: string;
};

type MappedPlanDetail = MappedPlanSummary & { days: MappedPlanDay[] };

type DecodedPlanCursor = { id: string; createdAt: string };

// ─── Helpers ──────────────────────────────────────────────────────────────────

const planDetailInclude = {
  planDays: {
    orderBy: { sortOrder: 'asc' as const },
    include: {
      exercises: {
        orderBy: { sortOrder: 'asc' as const },
        include: { exercise: true },
      },
    },
  },
} satisfies Prisma.WorkoutPlanInclude;

// Accepts ExerciseEntry (standalone) — also structurally compatible with entries
// pulled from PlanWithDays since both include { exercise: true }.
function mapPlanDayExercise(entry: ExerciseEntry): MappedPlanDayExercise {
  return {
    id: entry.id,
    exerciseId: entry.exercise.id,
    exerciseName: entry.exercise.name,
    exerciseType: entry.exercise.exerciseType,
    sortOrder: entry.sortOrder,
    targetSets: entry.targetSets,
    targetReps: entry.targetReps,
    targetDurationSec: entry.targetDurationSec,
    targetDistanceM: entry.targetDistanceM,
    notes: entry.notes,
    createdAt: entry.createdAt.toISOString(),
    updatedAt: entry.updatedAt.toISOString(),
  };
}

function mapPlanDay(day: PlanDayWithExercises): MappedPlanDay {
  return {
    id: day.id,
    dayOfWeek: day.dayOfWeek,
    weekNumber: day.weekNumber,
    name: day.name,
    sortOrder: day.sortOrder,
    exercises: day.exercises.map(mapPlanDayExercise),
  };
}

function mapPlanSummary(plan: {
  id: string;
  name: string;
  description: string | null;
  isActive: boolean;
  scheduleType: string;
  weeksCount: number | null;
  createdAt: Date;
  updatedAt: Date;
}): MappedPlanSummary {
  return {
    id: plan.id,
    name: plan.name,
    description: plan.description,
    isActive: plan.isActive,
    scheduleType: plan.scheduleType,
    weeksCount: plan.weeksCount,
    createdAt: plan.createdAt.toISOString(),
    updatedAt: plan.updatedAt.toISOString(),
  };
}

function mapPlanDetail(plan: PlanWithDays): MappedPlanDetail {
  return {
    ...mapPlanSummary(plan),
    days: plan.planDays.map(mapPlanDay),
  };
}

function encodePlanCursor(plan: { id: string; createdAt: Date }): string {
  const payload: DecodedPlanCursor = { id: plan.id, createdAt: plan.createdAt.toISOString() };
  return Buffer.from(JSON.stringify(payload)).toString('base64url');
}

function decodePlanCursor(cursor: string): DecodedPlanCursor {
  try {
    const raw = Buffer.from(cursor, 'base64url').toString('utf8');
    const parsed = JSON.parse(raw) as unknown;
    if (
      typeof parsed === 'object' &&
      parsed !== null &&
      // Strictly two keys — no extra fields accepted
      Object.keys(parsed as object).length === 2 &&
      'id' in parsed &&
      'createdAt' in parsed &&
      typeof (parsed as Record<string, unknown>).id === 'string' &&
      typeof (parsed as Record<string, unknown>).createdAt === 'string'
    ) {
      return parsed as DecodedPlanCursor;
    }
  } catch {
    // fall through
  }
  throw new AppError(400, 'Invalid or expired pagination cursor');
}

// ─── Handlers ─────────────────────────────────────────────────────────────────

export const listPlans = async (_req: Request, res: Response): Promise<void> => {
  const { cursor, limit } = res.locals.validated!.query as {
    cursor?: string;
    limit: number;
  };
  const { userId } = res.locals.auth!;

  const where: Prisma.WorkoutPlanWhereInput = { userId, deletedAt: null };

  if (cursor) {
    const decoded = decodePlanCursor(cursor);
    const cursorDate = new Date(decoded.createdAt);
    // Keyset condition for ORDER BY createdAt DESC, id ASC:
    // next page = rows with (createdAt < cursor) OR (createdAt = cursor AND id > cursorId)
    where.OR = [
      { createdAt: { lt: cursorDate } },
      { AND: [{ createdAt: cursorDate }, { id: { gt: decoded.id } }] },
    ];
  }

  const rows = await prisma.workoutPlan.findMany({
    where,
    orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
    take: limit + 1,
  });

  const hasMore = rows.length > limit;
  const data = hasMore ? rows.slice(0, limit) : rows;
  const nextCursor = hasMore ? encodePlanCursor(data.at(-1)!) : null;

  sendSuccess(res, {
    plans: data.map(mapPlanSummary),
    pagination: { next_cursor: nextCursor, has_more: hasMore, limit },
  });
};

export const getPlan = async (_req: Request, res: Response): Promise<void> => {
  const { id } = res.locals.validated!.params as { id: string };
  const { userId } = res.locals.auth!;

  const plan = await prisma.workoutPlan.findFirst({
    where: { id, userId, deletedAt: null },
    include: planDetailInclude,
  });

  if (!plan) throw new AppError(404, 'Workout plan not found');

  sendSuccess(res, { plan: mapPlanDetail(plan) });
};

export const createPlan = async (_req: Request, res: Response): Promise<void> => {
  const { name, description, scheduleType, weeksCount, days } = res.locals.validated!.body as {
    name: string;
    description?: string;
    scheduleType: 'weekly' | 'recurring';
    weeksCount?: number;
    days?: Array<{
      dayOfWeek: number;
      weekNumber?: number;
      name?: string;
      sortOrder: number;
    }>;
  };
  const { userId } = res.locals.auth!;

  const plan = await prisma.$transaction(async (tx) => {
    return tx.workoutPlan.create({
      data: {
        userId,
        name,
        description,
        scheduleType,
        weeksCount,
        planDays: days?.length
          ? {
              createMany: {
                data: days.map((d) => ({
                  dayOfWeek: d.dayOfWeek,
                  weekNumber: d.weekNumber ?? null,
                  name: d.name ?? null,
                  sortOrder: d.sortOrder,
                })),
              },
            }
          : undefined,
      },
      include: planDetailInclude,
    });
  });

  sendSuccess(res, { plan: mapPlanDetail(plan) }, 201);
};

export const updatePlan = async (_req: Request, res: Response): Promise<void> => {
  const { id } = res.locals.validated!.params as { id: string };
  const body = res.locals.validated!.body as {
    name?: string;
    description?: string;
    scheduleType?: 'weekly' | 'recurring';
    weeksCount?: number;
    isActive?: boolean;
  };
  const { userId } = res.locals.auth!;

  // Inline ownership + existence check in the WHERE clause — atomic, no TOCTOU race.
  try {
    const updated = await prisma.workoutPlan.update({
      where: { id, userId, deletedAt: null },
      data: {
        ...(body.name !== undefined && { name: body.name }),
        ...(body.description !== undefined && { description: body.description }),
        ...(body.scheduleType !== undefined && { scheduleType: body.scheduleType }),
        ...(body.weeksCount !== undefined && { weeksCount: body.weeksCount }),
        ...(body.isActive !== undefined && { isActive: body.isActive }),
      },
    });
    sendSuccess(res, { plan: mapPlanSummary(updated) });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      throw new AppError(404, 'Workout plan not found');
    }
    throw err;
  }
};

export const deletePlan = async (_req: Request, res: Response): Promise<void> => {
  const { id } = res.locals.validated!.params as { id: string };
  const { userId } = res.locals.auth!;

  // Inline ownership + existence check in the WHERE clause — atomic, no TOCTOU race.
  try {
    await prisma.workoutPlan.update({
      where: { id, userId, deletedAt: null },
      data: { deletedAt: new Date() },
    });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      throw new AppError(404, 'Workout plan not found');
    }
    throw err;
  }

  res.status(204).end();
};

export const addExercise = async (_req: Request, res: Response): Promise<void> => {
  const { id: planId } = res.locals.validated!.params as { id: string };
  const body = res.locals.validated!.body as {
    planDayId: string;
    exerciseId: string;
    sortOrder: number;
    targetSets?: number;
    targetReps?: string;
    targetDurationSec?: number;
    targetDistanceM?: number;
    notes?: string;
  };
  const { userId } = res.locals.auth!;

  // Wrap all checks + create in a transaction so the FK verification is atomic
  // with the insert — preventing races where a planDay or exercise is deleted
  // between the check and the create.
  const entry = await prisma.$transaction(async (tx) => {
    // Ownership check: plan must belong to user and not be soft-deleted.
    // The planDay query below already filters on planId, but we verify deletedAt
    // here because planDay has no deletedAt of its own.
    const plan = await tx.workoutPlan.findFirst({
      where: { id: planId, userId, deletedAt: null },
      select: { id: true },
    });
    if (!plan) throw new AppError(404, 'Workout plan not found');

    // Verify planDay belongs to this (non-deleted) plan.
    const planDay = await tx.planDay.findFirst({
      where: { id: body.planDayId, planId },
      select: { id: true },
    });
    if (!planDay) throw new AppError(404, 'Plan day not found');

    // Verify the exercise exists in the library.
    const exercise = await tx.exercise.findUnique({
      where: { id: body.exerciseId },
      select: { id: true },
    });
    if (!exercise) throw new AppError(404, 'Exercise not found');

    // Enforce sortOrder uniqueness within this plan day.
    const sortConflict = await tx.planDayExercise.findFirst({
      where: { planDayId: body.planDayId, sortOrder: body.sortOrder },
      select: { id: true },
    });
    if (sortConflict) {
      throw new AppError(
        422,
        `sortOrder ${body.sortOrder} is already in use for this plan day`,
      );
    }

    return tx.planDayExercise.create({
      data: {
        planDayId: body.planDayId,
        exerciseId: body.exerciseId,
        sortOrder: body.sortOrder,
        targetSets: body.targetSets ?? null,
        targetReps: body.targetReps ?? null,
        targetDurationSec: body.targetDurationSec ?? null,
        targetDistanceM: body.targetDistanceM ?? null,
        notes: body.notes ?? null,
      },
      include: { exercise: true },
    });
  });

  sendSuccess(res, { exercise: mapPlanDayExercise(entry) }, 201);
};

export const reorderExercises = async (_req: Request, res: Response): Promise<void> => {
  const { id: planId } = res.locals.validated!.params as { id: string };
  const { planDayId, planDayExerciseIds } = res.locals.validated!.body as {
    planDayId: string;
    planDayExerciseIds: string[];
  };
  const { userId } = res.locals.auth!;

  // Single query that verifies planDay existence, plan membership, and user ownership.
  const planDay = await prisma.planDay.findFirst({
    where: { id: planDayId, planId, plan: { userId, deletedAt: null } },
    select: { id: true },
  });
  if (!planDay) throw new AppError(404, 'Plan day not found');

  // Fetch all existing exercise entries for this plan day.
  const existing = await prisma.planDayExercise.findMany({
    where: { planDayId },
    select: { id: true },
  });

  const existingIds = new Set(existing.map((e) => e.id));
  const providedIds = new Set(planDayExerciseIds);

  // Require an exact match — no extras, no missing — so sortOrder stays contiguous.
  const hasMissing = [...existingIds].some((id) => !providedIds.has(id));
  const hasExtra = [...providedIds].some((id) => !existingIds.has(id));

  if (hasMissing || hasExtra) {
    throw new AppError(
      422,
      'planDayExerciseIds must contain exactly all exercise IDs for this plan day',
    );
  }

  // Update sortOrder = array index for each entry in a single transaction.
  try {
    await prisma.$transaction(
      planDayExerciseIds.map((entryId, index) =>
        prisma.planDayExercise.update({
          where: { id: entryId },
          data: { sortOrder: index },
        }),
      ),
    );
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      // Should not happen after the exact-set-match check above, but guards any race.
      throw new AppError(404, 'One or more exercise entries not found');
    }
    throw err;
  }

  const reordered = await prisma.planDayExercise.findMany({
    where: { planDayId },
    orderBy: { sortOrder: 'asc' },
    include: { exercise: true },
  });

  sendSuccess(res, { exercises: reordered.map(mapPlanDayExercise) });
};

export const updateExercise = async (_req: Request, res: Response): Promise<void> => {
  const { id: planId, planDayExId } = res.locals.validated!.params as {
    id: string;
    planDayExId: string;
  };
  const body = res.locals.validated!.body as {
    sortOrder?: number;
    targetSets?: number;
    targetReps?: string;
    targetDurationSec?: number;
    targetDistanceM?: number;
    notes?: string | null;
  };
  const { userId } = res.locals.auth!;

  // Single query that validates the full ownership chain:
  // planDayExercise → planDay → plan (owned by user, not soft-deleted).
  const existing = await prisma.planDayExercise.findFirst({
    where: {
      id: planDayExId,
      planDay: { planId, plan: { userId, deletedAt: null } },
    },
    select: { id: true, planDayId: true },
  });
  if (!existing) throw new AppError(404, 'Exercise entry not found');

  // Enforce sortOrder uniqueness within the day if sortOrder is being changed.
  if (body.sortOrder !== undefined) {
    const sortConflict = await prisma.planDayExercise.findFirst({
      where: {
        planDayId: existing.planDayId,
        sortOrder: body.sortOrder,
        id: { not: planDayExId },
      },
      select: { id: true },
    });
    if (sortConflict) {
      throw new AppError(
        422,
        `sortOrder ${body.sortOrder} is already in use for this plan day`,
      );
    }
  }

  try {
    const updated = await prisma.planDayExercise.update({
      where: { id: planDayExId },
      data: {
        ...(body.sortOrder !== undefined && { sortOrder: body.sortOrder }),
        ...(body.targetSets !== undefined && { targetSets: body.targetSets }),
        ...(body.targetReps !== undefined && { targetReps: body.targetReps }),
        ...(body.targetDurationSec !== undefined && {
          targetDurationSec: body.targetDurationSec,
        }),
        ...(body.targetDistanceM !== undefined && { targetDistanceM: body.targetDistanceM }),
        // Use 'in' check so that explicitly passing null clears the field.
        ...('notes' in body && { notes: body.notes }),
      },
      include: { exercise: true },
    });
    sendSuccess(res, { exercise: mapPlanDayExercise(updated) });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
      throw new AppError(404, 'Exercise entry not found');
    }
    throw err;
  }
};

export const removeExercise = async (_req: Request, res: Response): Promise<void> => {
  const { id: planId, planDayExId } = res.locals.validated!.params as {
    id: string;
    planDayExId: string;
  };
  const { userId } = res.locals.auth!;

  // Single query that validates the full ownership chain.
  const existing = await prisma.planDayExercise.findFirst({
    where: {
      id: planDayExId,
      planDay: { planId, plan: { userId, deletedAt: null } },
    },
    select: { id: true },
  });
  if (!existing) throw new AppError(404, 'Exercise entry not found');

  try {
    await prisma.planDayExercise.delete({ where: { id: planDayExId } });
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
