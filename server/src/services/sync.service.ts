import { type Prisma } from '../generated/prisma/client.js';
import { prisma } from '../lib/prisma.js';
import type { SupportedTable } from '../schemas/sync.schema.js';

// ─── Push helpers ─────────────────────────────────────────────────────────────

type SyncItem = {
  id: string;
  entityTable: SupportedTable;
  recordId: string;
  operation: 'create' | 'update' | 'delete';
  payload: Record<string, unknown>;
};

type ItemResult = { id: string; status: 'ok' | 'error'; error?: string };

// Prisma interactive transaction client — all apply* functions receive this
// so that the ownership SELECT and the upsert/delete are atomic (no TOCTOU).
type TxClient = Prisma.TransactionClient;

// ─── Date helpers ─────────────────────────────────────────────────────────────

/**
 * Throws if val is not a valid ISO date string.
 * Use for required date fields so callers get a clear error instead of
 * a silently-wrong default (e.g. `?? new Date()` would store "now" for any
 * session whose payload was missing startedAt — corrupting query results).
 */
function requireDate(val: unknown, fieldName: string): Date {
  if (val == null) throw new Error(`Missing required date field: ${fieldName}`);
  const d = new Date(val as string);
  if (isNaN(d.getTime())) {
    throw new Error(`Invalid date for field ${fieldName}: ${String(val)}`);
  }
  return d;
}

/** Coerce optional ISO string to Date; returns null for missing/invalid values. */
function toDate(val: unknown): Date | null {
  if (val == null) return null;
  const d = new Date(val as string);
  return isNaN(d.getTime()) ? null : d;
}

// ─── Table-specific upsert/delete handlers ────────────────────────────────────

async function applyWorkoutSession(
  item: SyncItem,
  userId: string,
  tx: TxClient,
): Promise<void> {
  const p = item.payload;
  if (item.operation === 'delete') {
    await tx.workoutSession.deleteMany({
      where: { id: item.recordId, userId },
    });
    return;
  }

  // Ownership check: reject updates targeting a session owned by another user.
  if (item.operation === 'update') {
    const existing = await tx.workoutSession.findUnique({
      where: { id: item.recordId },
      select: { userId: true },
    });
    if (existing && existing.userId !== userId) {
      throw new Error(`Forbidden: session ${item.recordId} belongs to another user`);
    }
  }

  await tx.workoutSession.upsert({
    where: { id: item.recordId },
    create: {
      id: item.recordId,
      userId,
      planId: (p.planId as string) ?? null,
      planDayId: (p.planDayId as string) ?? null,
      startedAt: requireDate(p.startedAt, 'startedAt'),
      completedAt: toDate(p.completedAt),
      durationSec: (p.durationSec as number) ?? null,
      notes: (p.notes as string) ?? null,
      status: (p.status as 'in_progress' | 'completed' | 'abandoned') ?? 'in_progress',
    },
    update: {
      planId: (p.planId as string) ?? null,
      planDayId: (p.planDayId as string) ?? null,
      startedAt: requireDate(p.startedAt, 'startedAt'),
      completedAt: toDate(p.completedAt),
      durationSec: (p.durationSec as number) ?? null,
      notes: (p.notes as string) ?? null,
      status: (p.status as 'in_progress' | 'completed' | 'abandoned') ?? 'in_progress',
    },
  });
}

async function applyExerciseLog(
  item: SyncItem,
  userId: string,
  tx: TxClient,
): Promise<void> {
  const p = item.payload;
  if (item.operation === 'delete') {
    // Guard: only delete if the parent session belongs to this user.
    await tx.exerciseLog.deleteMany({
      where: { id: item.recordId, session: { userId } },
    });
    return;
  }

  const sessionId = p.sessionId as string;

  // Ownership check: verify parent session belongs to this user.
  const session = await tx.workoutSession.findUnique({
    where: { id: sessionId },
    select: { userId: true },
  });
  if (!session || session.userId !== userId) {
    throw new Error(
      `Forbidden: session ${sessionId} not found or belongs to another user`,
    );
  }

  // For updates, also verify the log itself belongs to the claimed session.
  if (item.operation === 'update') {
    const existing = await tx.exerciseLog.findUnique({
      where: { id: item.recordId },
      select: { sessionId: true },
    });
    if (existing && existing.sessionId !== sessionId) {
      throw new Error(
        `Forbidden: exercise log ${item.recordId} belongs to a different session`,
      );
    }
  }

  await tx.exerciseLog.upsert({
    where: { id: item.recordId },
    create: {
      id: item.recordId,
      sessionId,
      exerciseId: p.exerciseId as string,
      sortOrder: (p.sortOrder as number) ?? 0,
      notes: (p.notes as string) ?? null,
    },
    update: {
      sortOrder: (p.sortOrder as number) ?? 0,
      notes: (p.notes as string) ?? null,
    },
  });
}

async function applySetLog(
  item: SyncItem,
  userId: string,
  tx: TxClient,
): Promise<void> {
  const p = item.payload;
  if (item.operation === 'delete') {
    await tx.setLog.deleteMany({
      where: { id: item.recordId, exerciseLog: { session: { userId } } },
    });
    return;
  }

  const exerciseLogId = p.exerciseLogId as string;

  // Ownership check: verify parent exercise log → session → user.
  const exerciseLog = await tx.exerciseLog.findUnique({
    where: { id: exerciseLogId },
    select: { session: { select: { userId: true } } },
  });
  if (!exerciseLog || exerciseLog.session.userId !== userId) {
    throw new Error(
      `Forbidden: exercise log ${exerciseLogId} not found or belongs to another user`,
    );
  }

  // For updates, verify the set log belongs to the claimed exercise log.
  if (item.operation === 'update') {
    const existing = await tx.setLog.findUnique({
      where: { id: item.recordId },
      select: { exerciseLogId: true },
    });
    if (existing && existing.exerciseLogId !== exerciseLogId) {
      throw new Error(
        `Forbidden: set log ${item.recordId} belongs to a different exercise log`,
      );
    }
  }

  await tx.setLog.upsert({
    where: { id: item.recordId },
    create: {
      id: item.recordId,
      exerciseLogId,
      setNumber: (p.setNumber as number) ?? 1,
      reps: (p.reps as number) ?? null,
      weightKg: (p.weightKg as number) ?? null,
      durationSec: (p.durationSec as number) ?? null,
      distanceM: (p.distanceM as number) ?? null,
      paceSecPerKm: (p.paceSecPerKm as number) ?? null,
      heartRate: (p.heartRate as number) ?? null,
      rpe: (p.rpe as number) ?? null,
      tempo: (p.tempo as string) ?? null,
      isWarmup: (p.isWarmup as boolean) ?? false,
      completedAt: toDate(p.completedAt),
    },
    update: {
      setNumber: (p.setNumber as number) ?? 1,
      reps: (p.reps as number) ?? null,
      weightKg: (p.weightKg as number) ?? null,
      durationSec: (p.durationSec as number) ?? null,
      distanceM: (p.distanceM as number) ?? null,
      paceSecPerKm: (p.paceSecPerKm as number) ?? null,
      heartRate: (p.heartRate as number) ?? null,
      rpe: (p.rpe as number) ?? null,
      tempo: (p.tempo as string) ?? null,
      isWarmup: (p.isWarmup as boolean) ?? false,
      completedAt: toDate(p.completedAt),
    },
  });
}

async function applyWorkoutPlan(
  item: SyncItem,
  userId: string,
  tx: TxClient,
): Promise<void> {
  const p = item.payload;
  if (item.operation === 'delete') {
    await tx.workoutPlan.updateMany({
      where: { id: item.recordId, userId },
      data: { deletedAt: new Date() },
    });
    return;
  }

  // Ownership check: reject updates targeting a plan owned by another user.
  if (item.operation === 'update') {
    const existing = await tx.workoutPlan.findUnique({
      where: { id: item.recordId },
      select: { userId: true },
    });
    if (existing && existing.userId !== userId) {
      throw new Error(`Forbidden: plan ${item.recordId} belongs to another user`);
    }
  }

  await tx.workoutPlan.upsert({
    where: { id: item.recordId },
    create: {
      id: item.recordId,
      userId,
      name: p.name as string,
      description: (p.description as string) ?? null,
      isActive: (p.isActive as boolean) ?? false,
      scheduleType: (p.scheduleType as 'weekly' | 'recurring') ?? 'weekly',
      weeksCount: (p.weeksCount as number) ?? null,
    },
    update: {
      name: p.name as string,
      description: (p.description as string) ?? null,
      isActive: (p.isActive as boolean) ?? false,
      scheduleType: (p.scheduleType as 'weekly' | 'recurring') ?? 'weekly',
      weeksCount: (p.weeksCount as number) ?? null,
    },
  });
}

async function applyPlanDay(
  item: SyncItem,
  userId: string,
  tx: TxClient,
): Promise<void> {
  const p = item.payload;
  if (item.operation === 'delete') {
    await tx.planDay.deleteMany({
      where: { id: item.recordId, plan: { userId } },
    });
    return;
  }

  const planId = p.planId as string;

  // Ownership check: verify parent plan belongs to this user.
  const plan = await tx.workoutPlan.findUnique({
    where: { id: planId },
    select: { userId: true },
  });
  if (!plan || plan.userId !== userId) {
    throw new Error(
      `Forbidden: plan ${planId} not found or belongs to another user`,
    );
  }

  // For updates, verify the day belongs to the claimed plan.
  if (item.operation === 'update') {
    const existing = await tx.planDay.findUnique({
      where: { id: item.recordId },
      select: { planId: true },
    });
    if (existing && existing.planId !== planId) {
      throw new Error(
        `Forbidden: plan day ${item.recordId} belongs to a different plan`,
      );
    }
  }

  await tx.planDay.upsert({
    where: { id: item.recordId },
    create: {
      id: item.recordId,
      planId,
      dayOfWeek: (p.dayOfWeek as number) ?? 0,
      weekNumber: (p.weekNumber as number) ?? null,
      name: (p.name as string) ?? null,
      sortOrder: (p.sortOrder as number) ?? 0,
    },
    update: {
      dayOfWeek: (p.dayOfWeek as number) ?? 0,
      weekNumber: (p.weekNumber as number) ?? null,
      name: (p.name as string) ?? null,
      sortOrder: (p.sortOrder as number) ?? 0,
    },
  });
}

async function applyPlanDayExercise(
  item: SyncItem,
  userId: string,
  tx: TxClient,
): Promise<void> {
  const p = item.payload;
  if (item.operation === 'delete') {
    await tx.planDayExercise.deleteMany({
      where: { id: item.recordId, planDay: { plan: { userId } } },
    });
    return;
  }

  const planDayId = p.planDayId as string;

  // Ownership check: verify parent plan day → plan → user.
  const planDay = await tx.planDay.findUnique({
    where: { id: planDayId },
    select: { plan: { select: { userId: true } } },
  });
  if (!planDay || planDay.plan.userId !== userId) {
    throw new Error(
      `Forbidden: plan day ${planDayId} not found or belongs to another user`,
    );
  }

  // For updates, verify the exercise belongs to the claimed plan day.
  if (item.operation === 'update') {
    const existing = await tx.planDayExercise.findUnique({
      where: { id: item.recordId },
      select: { planDayId: true },
    });
    if (existing && existing.planDayId !== planDayId) {
      throw new Error(
        `Forbidden: plan day exercise ${item.recordId} belongs to a different plan day`,
      );
    }
  }

  await tx.planDayExercise.upsert({
    where: { id: item.recordId },
    create: {
      id: item.recordId,
      planDayId,
      exerciseId: p.exerciseId as string,
      sortOrder: (p.sortOrder as number) ?? 0,
      targetSets: (p.targetSets as number) ?? null,
      targetReps: (p.targetReps as string) ?? null,
      targetDurationSec: (p.targetDurationSec as number) ?? null,
      targetDistanceM: (p.targetDistanceM as number) ?? null,
      notes: (p.notes as string) ?? null,
    },
    update: {
      sortOrder: (p.sortOrder as number) ?? 0,
      targetSets: (p.targetSets as number) ?? null,
      targetReps: (p.targetReps as string) ?? null,
      targetDurationSec: (p.targetDurationSec as number) ?? null,
      targetDistanceM: (p.targetDistanceM as number) ?? null,
      notes: (p.notes as string) ?? null,
    },
  });
}

// ─── Public: processPushItems ─────────────────────────────────────────────────

export async function processPushItems(
  items: SyncItem[],
  userId: string,
): Promise<ItemResult[]> {
  const results: ItemResult[] = [];

  for (const item of items) {
    try {
      // Each item runs in its own transaction so that the ownership SELECT
      // and the upsert/delete are atomic (no TOCTOU race). An error in one
      // item rolls back only that item — other items are unaffected.
      await prisma.$transaction(async (tx) => {
        switch (item.entityTable) {
          case 'workout_sessions':
            await applyWorkoutSession(item, userId, tx);
            break;
          case 'exercise_logs':
            await applyExerciseLog(item, userId, tx);
            break;
          case 'set_logs':
            await applySetLog(item, userId, tx);
            break;
          case 'workout_plans':
            await applyWorkoutPlan(item, userId, tx);
            break;
          case 'plan_days':
            await applyPlanDay(item, userId, tx);
            break;
          case 'plan_day_exercises':
            await applyPlanDayExercise(item, userId, tx);
            break;
        }
      });
      results.push({ id: item.id, status: 'ok' });
    } catch (err) {
      results.push({
        id: item.id,
        status: 'error',
        error: err instanceof Error ? err.message : 'Unknown error',
      });
    }
  }

  return results;
}

// ─── Public: fetchPullData ────────────────────────────────────────────────────

export async function fetchPullData(
  userId: string,
  since?: Date,
): Promise<{
  sessions: Awaited<ReturnType<typeof prisma.workoutSession.findMany>>;
  exerciseLogs: Awaited<ReturnType<typeof prisma.exerciseLog.findMany>>;
  setLogs: Awaited<ReturnType<typeof prisma.setLog.findMany>>;
  plans: Awaited<ReturnType<typeof prisma.workoutPlan.findMany>>;
  planDays: Awaited<ReturnType<typeof prisma.planDay.findMany>>;
  planDayExercises: Awaited<ReturnType<typeof prisma.planDayExercise.findMany>>;
}> {
  const sinceFilter = since ? { gt: since } : undefined;

  const [sessions, exerciseLogs, setLogs, plans, planDays, planDayExercises] =
    await Promise.all([
      // Workout sessions
      prisma.workoutSession.findMany({
        where: {
          userId,
          ...(sinceFilter ? { updatedAt: sinceFilter } : {}),
        },
        orderBy: { startedAt: 'desc' },
      }),

      // Exercise logs (scoped via session → userId)
      prisma.exerciseLog.findMany({
        where: {
          session: { userId },
          ...(sinceFilter ? { updatedAt: sinceFilter } : {}),
        },
      }),

      // Set logs (scoped via exerciseLog → session → userId)
      prisma.setLog.findMany({
        where: {
          exerciseLog: { session: { userId } },
          ...(sinceFilter ? { updatedAt: sinceFilter } : {}),
        },
      }),

      // Workout plans (non-deleted)
      prisma.workoutPlan.findMany({
        where: {
          userId,
          deletedAt: null,
          ...(sinceFilter ? { updatedAt: sinceFilter } : {}),
        },
      }),

      // Plan days (scoped via plan → userId)
      prisma.planDay.findMany({
        where: {
          plan: { userId, deletedAt: null },
          ...(sinceFilter ? { updatedAt: sinceFilter } : {}),
        },
      }),

      // Plan day exercises (scoped via planDay → plan → userId)
      prisma.planDayExercise.findMany({
        where: {
          planDay: { plan: { userId, deletedAt: null } },
          ...(sinceFilter ? { updatedAt: sinceFilter } : {}),
        },
      }),
    ]);

  return { sessions, exerciseLogs, setLogs, plans, planDays, planDayExercises };
}
