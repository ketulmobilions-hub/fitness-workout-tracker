import type { Request, Response } from 'express';
import { sendSuccess } from '../utils/response.js';
import { processPushItems, fetchPullData } from '../services/sync.service.js';
import type { SyncPushBody, SyncPullQuery } from '../schemas/sync.schema.js';

export async function push(_req: Request, res: Response): Promise<void> {
  const userId = res.locals.auth!.userId as string;
  const { items } = res.locals.validated!.body as SyncPushBody;

  const results = await processPushItems(items, userId);

  sendSuccess(res, { results }, 200);
}

export async function pull(_req: Request, res: Response): Promise<void> {
  const userId = res.locals.auth!.userId as string;
  const { since } = res.locals.validated!.query as SyncPullQuery;

  const sinceDate = since ? new Date(since) : undefined;
  const data = await fetchPullData(userId, sinceDate);
  const syncedAt = new Date().toISOString();

  sendSuccess(res, {
    sessions: data.sessions.map((s) => ({
      id: s.id,
      planId: s.planId,
      planDayId: s.planDayId,
      startedAt: s.startedAt.toISOString(),
      completedAt: s.completedAt?.toISOString() ?? null,
      durationSec: s.durationSec,
      notes: s.notes,
      status: s.status,
      createdAt: s.createdAt.toISOString(),
      updatedAt: s.updatedAt.toISOString(),
    })),
    exerciseLogs: data.exerciseLogs.map((l) => ({
      id: l.id,
      sessionId: l.sessionId,
      exerciseId: l.exerciseId,
      sortOrder: l.sortOrder,
      notes: l.notes,
      createdAt: l.createdAt.toISOString(),
      updatedAt: l.updatedAt.toISOString(),
    })),
    setLogs: data.setLogs.map((s) => ({
      id: s.id,
      exerciseLogId: s.exerciseLogId,
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
    })),
    plans: data.plans.map((p) => ({
      id: p.id,
      name: p.name,
      description: p.description,
      isActive: p.isActive,
      scheduleType: p.scheduleType,
      weeksCount: p.weeksCount,
      createdAt: p.createdAt.toISOString(),
      updatedAt: p.updatedAt.toISOString(),
    })),
    planDays: data.planDays.map((d) => ({
      id: d.id,
      planId: d.planId,
      dayOfWeek: d.dayOfWeek,
      weekNumber: d.weekNumber,
      name: d.name,
      sortOrder: d.sortOrder,
      createdAt: d.createdAt.toISOString(),
      updatedAt: d.updatedAt.toISOString(),
    })),
    planDayExercises: data.planDayExercises.map((e) => ({
      id: e.id,
      planDayId: e.planDayId,
      exerciseId: e.exerciseId,
      sortOrder: e.sortOrder,
      targetSets: e.targetSets,
      targetReps: e.targetReps,
      targetDurationSec: e.targetDurationSec,
      targetDistanceM: e.targetDistanceM,
      notes: e.notes,
      createdAt: e.createdAt.toISOString(),
      updatedAt: e.updatedAt.toISOString(),
    })),
    syncedAt,
  });
}
