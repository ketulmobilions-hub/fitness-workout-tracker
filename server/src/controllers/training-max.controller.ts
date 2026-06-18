import type { Request, Response } from 'express';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../utils/errors.js';
import { sendSuccess } from '../utils/response.js';

type TrainingMaxItem = {
  id: string;
  exerciseId: string;
  exerciseName: string;
  exerciseType: string;
  trainingMaxKg: number;
  percentageOf1rm: number;
  latestPrKg: number | null;
  latestPrDate: string | null;
  updatedAt: string;
};

async function fetchLatestPrs(
  userId: string,
  exerciseIds: string[],
): Promise<Map<string, { value: number; achievedAt: Date }>> {
  if (exerciseIds.length === 0) return new Map();

  const rows = await prisma.$queryRaw<
    Array<{ exercise_id: string; value: number; achieved_at: Date }>
  >`
    SELECT DISTINCT ON (pr.exercise_id)
      pr.exercise_id,
      pr.value,
      pr.achieved_at
    FROM personal_records pr
    WHERE pr.user_id = ${userId}::uuid
      AND pr.exercise_id = ANY(${exerciseIds}::uuid[])
      AND pr.record_type = 'max_weight'
    ORDER BY pr.exercise_id, pr.value DESC
  `;

  const map = new Map<string, { value: number; achievedAt: Date }>();
  for (const row of rows) {
    map.set(row.exercise_id, { value: row.value, achievedAt: row.achieved_at });
  }
  return map;
}

function mapItem(
  tm: {
    id: string;
    exerciseId: string;
    exercise: { name: string; exerciseType: string };
    trainingMaxKg: number;
    percentageOf1rm: number;
    updatedAt: Date;
  },
  prMap: Map<string, { value: number; achievedAt: Date }>,
): TrainingMaxItem {
  const pr = prMap.get(tm.exerciseId);
  return {
    id: tm.id,
    exerciseId: tm.exerciseId,
    exerciseName: tm.exercise.name,
    exerciseType: tm.exercise.exerciseType,
    trainingMaxKg: tm.trainingMaxKg,
    percentageOf1rm: tm.percentageOf1rm,
    latestPrKg: pr?.value ?? null,
    latestPrDate: pr?.achievedAt.toISOString() ?? null,
    updatedAt: tm.updatedAt.toISOString(),
  };
}

export const list = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;

  const tms = await prisma.trainingMax.findMany({
    where: { userId },
    include: {
      exercise: { select: { name: true, exerciseType: true } },
    },
    orderBy: { updatedAt: 'desc' },
  });

  const prMap = await fetchLatestPrs(
    userId,
    tms.map((t) => t.exerciseId),
  );

  sendSuccess(res, tms.map((tm) => mapItem(tm, prMap)));
};

export const upsert = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { exerciseId } = res.locals.validated!.params as { exerciseId: string };
  const { trainingMaxKg, percentageOf1rm } = res.locals.validated!.body as {
    trainingMaxKg: number;
    percentageOf1rm?: number;
  };

  const exercise = await prisma.exercise.findUnique({
    where: { id: exerciseId },
    select: { name: true, exerciseType: true },
  });
  if (!exercise) throw new AppError(404, 'Exercise not found');
  if (exercise.exerciseType !== 'strength') {
    throw new AppError(422, 'Training maxes can only be set for strength exercises');
  }

  const pct = percentageOf1rm ?? 90;

  const tm = await prisma.trainingMax.upsert({
    where: { userId_exerciseId: { userId, exerciseId } },
    create: { userId, exerciseId, trainingMaxKg, percentageOf1rm: pct },
    update: { trainingMaxKg, percentageOf1rm: pct },
  });

  const prMap = await fetchLatestPrs(userId, [exerciseId]);

  sendSuccess(res, mapItem({ ...tm, exercise }, prMap));
};
