import type { Request, Response } from 'express';
import { prisma } from '../lib/prisma.js';
import { sendSuccess } from '../utils/response.js';

export const getStreak = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;

  const streak = await prisma.streak.findUnique({
    where: { userId },
    select: { currentStreak: true, longestStreak: true, lastWorkoutDate: true },
  });

  sendSuccess(res, {
    currentStreak: streak?.currentStreak ?? 0,
    longestStreak: streak?.longestStreak ?? 0,
    lastWorkoutDate: streak?.lastWorkoutDate
      ? streak.lastWorkoutDate.toISOString().slice(0, 10)
      : null,
  });
};

export const getStreakHistory = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { year, month } = res.locals.validated!.query as { year: number; month: number };

  // Build UTC boundaries for the requested calendar month.
  const startDate = new Date(Date.UTC(year, month - 1, 1));
  const endDate = new Date(Date.UTC(year, month, 1)); // exclusive upper bound

  const rows = await prisma.streakHistory.findMany({
    where: {
      userId,
      date: { gte: startDate, lt: endDate },
    },
    select: { date: true, status: true },
    orderBy: { date: 'asc' },
  });

  sendSuccess(res, {
    history: rows.map((r) => ({
      date: r.date.toISOString().slice(0, 10),
      status: r.status,
    })),
  });
};
