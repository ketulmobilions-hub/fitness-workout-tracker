import type { Request, Response } from 'express';
import { Prisma } from '../generated/prisma/client.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../utils/errors.js';
import { sendSuccess } from '../utils/response.js';
import { estimateOneRepMax } from '../utils/oneRmCalculator.js';
import { computeAllScores } from '../utils/strengthScores.js';

// ─── Types ────────────────────────────────────────────────────────────────────

type OneRmHistoryRow = {
  session_date: Date | string;
  weight_kg: string;
  reps: string;
};

// ExercisePeriod: periods valid for the exercise progress endpoint (no '1w').
type ExercisePeriod = '1m' | '3m' | '6m' | '1y' | 'all';

// VolumePeriod: periods valid for the volume endpoint (no 'all').
type VolumePeriod = '1w' | '1m' | '3m' | '6m' | '1y';

type Granularity = 'daily' | 'weekly' | 'monthly';

type PersonalRecordsMap = {
  maxWeight: number | null;
  maxReps: number | null;
  maxVolume: number | null;
  bestPace: number | null;
};

type ExerciseHistoryEntry = {
  date: string;
  maxWeight: number | null;
  totalVolume: number;
  totalReps: number;
  setsCount: number;
};

type VolumeSumRow = {
  volume: string;
};

type SbdBestRow = {
  category: 'squat' | 'bench' | 'deadlift';
  best_kg: string;
};

type ExerciseHistoryRow = {
  session_date: Date | string;
  max_weight: string | null;
  total_volume: string;
  total_reps: string;
  sets_count: bigint;
};

type BestSetRow = {
  weight_kg: string;
  reps: string;
};

type VolumeQueryRow = {
  bucket: Date;
  volume: string;
  sessions: bigint;
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

function getPeriodStart(period: ExercisePeriod | VolumePeriod): Date | null {
  if (period === 'all') return null;
  const dayMap: Record<Exclude<ExercisePeriod | VolumePeriod, 'all'>, number> = {
    '1w': 7,
    '1m': 30,
    '3m': 90,
    '6m': 180,
    '1y': 365,
  };
  const now = new Date();
  now.setDate(now.getDate() - dayMap[period]);
  now.setHours(0, 0, 0, 0);
  return now;
}

function inferGranularity(period: VolumePeriod): Granularity {
  if (period === '1w' || period === '1m') return 'daily';
  if (period === '3m' || period === '6m') return 'weekly';
  return 'monthly';
}

// Exhaustive switch — TypeScript will error if a new Granularity value is added
// without a corresponding case, preventing silent DATE_TRUNC failures.
function granularityToPgTrunc(g: Granularity): 'day' | 'week' | 'month' {
  switch (g) {
    case 'daily':
      return 'day';
    case 'weekly':
      return 'week';
    case 'monthly':
      return 'month';
  }
}


function toDateString(value: Date | string): string {
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  // PostgreSQL DATE columns sometimes come back as 'YYYY-MM-DD' strings
  return String(value).slice(0, 10);
}

// Returns the UTC timestamp that corresponds to the start of the user's local
// week (Monday 00:00) or month (1st 00:00), given their UTC offset in minutes.
// This ensures volume windows align with the user's calendar, not the server's.
function getLocalPeriodStart(periodType: 'week' | 'month', utcOffsetMinutes: number): Date {
  const nowUtc = new Date();
  // Shift to the user's local "clock" while keeping Date in UTC arithmetic
  const localNow = new Date(nowUtc.getTime() + utcOffsetMinutes * 60 * 1000);

  let localStart: Date;
  if (periodType === 'week') {
    // ISO week starts on Monday. getUTCDay() returns 0=Sun…6=Sat.
    const dayOfWeek = localNow.getUTCDay();
    const daysFromMonday = (dayOfWeek + 6) % 7;
    localStart = new Date(localNow);
    localStart.setUTCDate(localNow.getUTCDate() - daysFromMonday);
    localStart.setUTCHours(0, 0, 0, 0);
  } else {
    localStart = new Date(
      Date.UTC(localNow.getUTCFullYear(), localNow.getUTCMonth(), 1, 0, 0, 0, 0),
    );
  }

  // Shift back to UTC so the timestamp can be compared against stored UTC values
  return new Date(localStart.getTime() - utcOffsetMinutes * 60 * 1000);
}

// ─── Handlers ────────────────────────────────────────────────────────────────

export const getOverview = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { utc_offset: utcOffset } = res.locals.validated!.query as { utc_offset: number };

  const weekStart = getLocalPeriodStart('week', utcOffset);
  const monthStart = getLocalPeriodStart('month', utcOffset);

  const [totalWorkouts, weekVolumeRows, monthVolumeRows, streak, user] = await Promise.all([
    // Count only completed sessions — abandoned/in-progress are not real workouts
    prisma.workoutSession.count({
      where: { userId, status: 'completed' },
    }),
    prisma.$queryRaw<VolumeSumRow[]>`
      SELECT COALESCE(SUM(sl.weight_kg * sl.reps), 0) AS volume
      FROM workout_sessions ws
      JOIN exercise_logs el ON el.session_id = ws.id
      JOIN set_logs sl ON sl.exercise_log_id = el.id
      WHERE ws.user_id = ${userId}::uuid
        AND ws.status = 'completed'
        AND ws.completed_at >= ${weekStart}::timestamptz
        AND sl.is_warmup = false
        AND sl.weight_kg IS NOT NULL
        AND sl.reps IS NOT NULL
    `,
    prisma.$queryRaw<VolumeSumRow[]>`
      SELECT COALESCE(SUM(sl.weight_kg * sl.reps), 0) AS volume
      FROM workout_sessions ws
      JOIN exercise_logs el ON el.session_id = ws.id
      JOIN set_logs sl ON sl.exercise_log_id = el.id
      WHERE ws.user_id = ${userId}::uuid
        AND ws.status = 'completed'
        AND ws.completed_at >= ${monthStart}::timestamptz
        AND sl.is_warmup = false
        AND sl.weight_kg IS NOT NULL
        AND sl.reps IS NOT NULL
    `,
    prisma.streak.findUnique({
      where: { userId },
      select: { currentStreak: true, longestStreak: true, lastWorkoutDate: true },
    }),
    // Fetch competition profile fields needed to compute strength scores.
    prisma.user.findUnique({
      where: { id: userId },
      select: { bodyweightKg: true, gender: true },
    }),
  ]);

  // Only query SBD PRs when we have the profile data needed to use them.
  // Avoids a wasted JOIN + aggregate on every overview load for athletes who
  // haven't set up their competition profile yet.
  let sbdRows: SbdBestRow[] = [];
  if (user?.bodyweightKg && user?.gender) {
    sbdRows = await prisma.$queryRaw<SbdBestRow[]>`
      SELECT
        CASE
          WHEN e.name ILIKE '%squat%' AND e.name NOT ILIKE '%hack squat%'
               AND e.name NOT ILIKE '%belt squat%' THEN 'squat'
          WHEN e.name ILIKE '%bench press%' THEN 'bench'
          WHEN e.name ILIKE '%deadlift%' AND e.name NOT ILIKE '%romanian%'
               AND e.name NOT ILIKE '%stiff%' AND e.name NOT ILIKE '%trap bar%' THEN 'deadlift'
        END AS category,
        MAX(pr.value) AS best_kg
      FROM personal_records pr
      JOIN exercises e ON e.id = pr.exercise_id
      WHERE pr.user_id = ${userId}::uuid
        AND pr.record_type = 'max_weight'
        AND (
          (e.name ILIKE '%squat%' AND e.name NOT ILIKE '%hack squat%'
           AND e.name NOT ILIKE '%belt squat%') OR
          (e.name ILIKE '%bench press%') OR
          (e.name ILIKE '%deadlift%' AND e.name NOT ILIKE '%romanian%'
           AND e.name NOT ILIKE '%stiff%' AND e.name NOT ILIKE '%trap bar%')
        )
      GROUP BY category
      HAVING MAX(pr.value) IS NOT NULL
    `;
  }

  // Scores are estimated from best all-time PRs per lift (not a real competition
  // total) — flag this so clients can surface an "estimated" label in the UI.
  let strengthScores: { wilks: number | null; dots: number | null; ipfGl: number | null } | null = null;
  if (user?.bodyweightKg && user?.gender) {
    const byCategory: Record<string, number> = {};
    for (const row of sbdRows) {
      if (row.category) byCategory[row.category] = Number(row.best_kg);
    }
    const { squat, bench, deadlift } = { squat: byCategory['squat'], bench: byCategory['bench'], deadlift: byCategory['deadlift'] };
    // Require all three lifts for a meaningful total — a partial total would
    // drastically understate the score and confuse athletes.
    if (squat != null && bench != null && deadlift != null) {
      const total = squat + bench + deadlift;
      strengthScores = computeAllScores(total, user.bodyweightKg, user.gender);
    }
  }

  sendSuccess(res, {
    totalWorkouts,
    volumeThisWeek: Number(weekVolumeRows[0]?.volume ?? 0),
    volumeThisMonth: Number(monthVolumeRows[0]?.volume ?? 0),
    currentStreak: streak?.currentStreak ?? 0,
    longestStreak: streak?.longestStreak ?? 0,
    lastWorkoutDate: streak?.lastWorkoutDate ? toDateString(streak.lastWorkoutDate) : null,
    wilks: strengthScores?.wilks ?? null,
    dots: strengthScores?.dots ?? null,
    ipfGl: strengthScores?.ipfGl ?? null,
    strengthScoresEstimated: strengthScores !== null,
  });
};

export const getExerciseProgress = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { id: exerciseId } = res.locals.validated!.params as { id: string };
  const { period } = res.locals.validated!.query as { period: ExercisePeriod };

  // Scope to exercises the user is allowed to see: system exercises (isCustom=false)
  // or custom exercises they created. Prevents disclosing other users' private exercise names.
  const exercise = await prisma.exercise.findFirst({
    where: {
      id: exerciseId,
      OR: [{ isCustom: false }, { createdBy: userId }],
    },
    select: { id: true, name: true, exerciseType: true },
  });
  if (!exercise) throw new AppError(404, 'Exercise not found');

  const start = getPeriodStart(period);

  const [prs, historyRows, bestSetRows] = await Promise.all([
    prisma.personalRecord.findMany({
      where: { userId, exerciseId },
      select: { recordType: true, value: true },
    }),
    prisma.$queryRaw<ExerciseHistoryRow[]>`
      SELECT
        DATE(ws.completed_at) AS session_date,
        -- Exclude warmup sets from max_weight to stay consistent with volume
        MAX(CASE WHEN sl.is_warmup = false THEN sl.weight_kg ELSE NULL END) AS max_weight,
        SUM(CASE WHEN sl.is_warmup = false AND sl.weight_kg IS NOT NULL AND sl.reps IS NOT NULL
             THEN sl.weight_kg * sl.reps ELSE 0 END) AS total_volume,
        SUM(CASE WHEN sl.reps IS NOT NULL THEN sl.reps ELSE 0 END) AS total_reps,
        COUNT(sl.id) AS sets_count
      FROM workout_sessions ws
      JOIN exercise_logs el ON el.session_id = ws.id AND el.exercise_id = ${exerciseId}::uuid
      JOIN set_logs sl ON sl.exercise_log_id = el.id
      WHERE ws.user_id = ${userId}::uuid
        AND ws.status = 'completed'
        AND (${start}::timestamptz IS NULL OR ws.completed_at >= ${start}::timestamptz)
      GROUP BY DATE(ws.completed_at)
      ORDER BY session_date ASC
    `,
    // Order by the Epley estimated 1RM (weight × (1 + reps/30)) so the set
    // that produces the highest strength estimate is chosen — not the highest-volume set.
    prisma.$queryRaw<BestSetRow[]>`
      SELECT sl.weight_kg, sl.reps
      FROM workout_sessions ws
      JOIN exercise_logs el ON el.session_id = ws.id AND el.exercise_id = ${exerciseId}::uuid
      JOIN set_logs sl ON sl.exercise_log_id = el.id
      WHERE ws.user_id = ${userId}::uuid
        AND ws.status = 'completed'
        AND sl.weight_kg IS NOT NULL
        AND sl.reps >= 1
        AND sl.reps <= 99
        AND sl.is_warmup = false
        AND (${start}::timestamptz IS NULL OR ws.completed_at >= ${start}::timestamptz)
      ORDER BY (sl.weight_kg * (1 + sl.reps / 30.0)) DESC
      LIMIT 1
    `,
  ]);

  // Build PR map: take the best value per record type
  const prBestMap: Record<string, number> = {};
  for (const pr of prs) {
    const existing = prBestMap[pr.recordType];
    const isPace = pr.recordType === 'best_pace';
    if (existing === undefined || (isPace ? pr.value < existing : pr.value > existing)) {
      prBestMap[pr.recordType] = pr.value;
    }
  }
  const personalRecords: PersonalRecordsMap = {
    maxWeight: prBestMap['max_weight'] ?? null,
    maxReps: prBestMap['max_reps'] ?? null,
    maxVolume: prBestMap['max_volume'] ?? null,
    bestPace: prBestMap['best_pace'] ?? null,
  };

  const bestSet = bestSetRows[0] ?? null;
  const estimatedOneRepMax =
    bestSet ? estimateOneRepMax(Number(bestSet.weight_kg), Number(bestSet.reps)) : null;

  const history: ExerciseHistoryEntry[] = historyRows.map((row) => ({
    date: toDateString(row.session_date),
    maxWeight: row.max_weight !== null ? Number(row.max_weight) : null,
    totalVolume: Number(row.total_volume),
    totalReps: Number(row.total_reps),
    setsCount: Number(row.sets_count),
  }));

  sendSuccess(res, {
    exercise: { id: exercise.id, name: exercise.name, type: exercise.exerciseType },
    personalRecords,
    estimatedOneRepMax,
    history,
  });
};

export const getPersonalRecords = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const query = (res.locals.validated?.query ?? {}) as {
    exercise_id?: string;
    record_type?: string;
  };

  const where: Prisma.PersonalRecordWhereInput = { userId };
  if (query.exercise_id) where.exerciseId = query.exercise_id;
  if (query.record_type) where.recordType = query.record_type as Prisma.EnumRecordTypeFilter;

  // Use distinct to return only the current best per (exercise, recordType).
  // The PR table stores every record-breaking event as a separate row; distinct
  // with achievedAt DESC keeps only the most recent (= best) row per pair.
  // orderBy must lead with the distinct fields so Prisma picks the correct row.
  // No take limit — the query is already scoped to one user and deduplicated,
  // so cardinality is bounded by (distinct exercises logged) × 4 record types.
  const records = await prisma.personalRecord.findMany({
    where,
    distinct: ['exerciseId', 'recordType'],
    orderBy: [{ exerciseId: 'asc' }, { recordType: 'asc' }, { achievedAt: 'desc' }],
    include: { exercise: { select: { id: true, name: true } } },
  });

  // Re-sort by exercise name for a friendlier presentation order
  records.sort((a, b) => {
    const nameCompare = a.exercise.name.localeCompare(b.exercise.name);
    return nameCompare !== 0 ? nameCompare : a.recordType.localeCompare(b.recordType);
  });

  sendSuccess(res, {
    data: records.map((pr) => ({
      id: pr.id,
      exercise: { id: pr.exercise.id, name: pr.exercise.name },
      recordType: pr.recordType,
      value: pr.value,
      achievedAt: pr.achievedAt.toISOString(),
      sessionId: pr.sessionId,
    })),
  });
};

export const get1RmHistory = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { exerciseId } = res.locals.validated!.params as { exerciseId: string };
  const { period } = res.locals.validated!.query as { period: ExercisePeriod };

  const exercise = await prisma.exercise.findFirst({
    where: { id: exerciseId, OR: [{ isCustom: false }, { createdBy: userId }] },
    select: { id: true, name: true },
  });
  if (!exercise) throw new AppError(404, 'Exercise not found');

  const start = getPeriodStart(period);

  // Fetch all qualifying sets and group in TypeScript so the set selected per
  // day uses the same estimateOneRepMax function as the displayed value — SQL's
  // inline Epley and the 3-formula average can disagree on which set "wins".
  const rows = await prisma.$queryRaw<OneRmHistoryRow[]>`
    SELECT
      DATE(ws.completed_at) AS session_date,
      sl.weight_kg,
      sl.reps
    FROM workout_sessions ws
    JOIN exercise_logs el ON el.session_id = ws.id AND el.exercise_id = ${exerciseId}::uuid
    JOIN set_logs sl ON sl.exercise_log_id = el.id
    WHERE ws.user_id = ${userId}::uuid
      AND ws.status = 'completed'
      AND sl.weight_kg IS NOT NULL
      AND sl.reps >= 1
      AND sl.reps <= 99
      AND sl.is_warmup = false
      AND (${start}::timestamptz IS NULL OR ws.completed_at >= ${start}::timestamptz)
    ORDER BY DATE(ws.completed_at) ASC
  `;

  // Pick the set with the highest estimated 1RM per calendar day.
  const byDate = new Map<string, number>();
  for (const row of rows) {
    const date = toDateString(row.session_date);
    const est = estimateOneRepMax(Number(row.weight_kg), Number(row.reps));
    const existing = byDate.get(date);
    if (existing === undefined || est > existing) {
      byDate.set(date, est);
    }
  }

  const history = Array.from(byDate.entries()).map(([date, estimatedOneRepMax]) => ({
    date,
    estimatedOneRepMax,
  }));

  sendSuccess(res, {
    exercise: { id: exercise.id, name: exercise.name },
    history,
  });
};

export const getVolume = async (_req: Request, res: Response): Promise<void> => {
  const { userId } = res.locals.auth!;
  const { period, granularity } = res.locals.validated!.query as {
    period: VolumePeriod;
    granularity?: Granularity;
  };

  const resolvedGranularity: Granularity = granularity ?? inferGranularity(period);
  const start = getPeriodStart(period)!; // volume endpoint has no 'all' option

  // granularityToPgTrunc uses an exhaustive switch — TypeScript will catch any
  // future Granularity additions that aren't mapped here at compile time.
  const pgTrunc = granularityToPgTrunc(resolvedGranularity);

  // Prisma.raw is safe here: pgTrunc is only ever 'day', 'week', or 'month'
  // from the exhaustive switch above — never from raw user input.
  const truncFragment = Prisma.raw(`'${pgTrunc}'`);

  const result = await prisma.$queryRaw<VolumeQueryRow[]>(Prisma.sql`
    SELECT
      DATE_TRUNC(${truncFragment}, ws.completed_at) AS bucket,
      COALESCE(SUM(
        CASE WHEN sl.is_warmup = false AND sl.weight_kg IS NOT NULL AND sl.reps IS NOT NULL
             THEN sl.weight_kg * sl.reps ELSE 0 END
      ), 0) AS volume,
      COUNT(DISTINCT ws.id) AS sessions
    FROM workout_sessions ws
    JOIN exercise_logs el ON el.session_id = ws.id
    JOIN set_logs sl ON sl.exercise_log_id = el.id
    WHERE ws.user_id = ${userId}::uuid
      AND ws.status = 'completed'
      AND ws.completed_at >= ${start}::timestamptz
    GROUP BY DATE_TRUNC(${truncFragment}, ws.completed_at)
    ORDER BY bucket ASC
  `);

  sendSuccess(res, {
    granularity: resolvedGranularity,
    data: result.map((row) => ({
      date: toDateString(row.bucket),
      volume: Number(row.volume),
      sessions: Number(row.sessions),
    })),
  });
};
