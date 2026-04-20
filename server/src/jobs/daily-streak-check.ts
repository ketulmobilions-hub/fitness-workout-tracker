import { prisma } from '../lib/prisma.js';

function getYesterdayUTC(): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().slice(0, 10);
}

type PlanRow = {
  id: string;
  userId: string;
  scheduleType: string;
  weeksCount: number | null;
  createdAt: Date;
  planDays: { id: string; dayOfWeek: number; weekNumber: number | null }[];
};

// Returns IDs of the plan days scheduled for a given UTC date string.
// An empty result means the date is a rest day for this plan.
//
// For recurring plans the cycle week is anchored to plan.createdAt. If a plan
// is created well before it is activated the offset will be off by that gap.
// A future schema field (activatedAt) would fix this; for MVP it is documented
// as a known limitation.
function getMatchingPlanDayIds(plan: PlanRow, dateStr: string): string[] {
  const date = new Date(`${dateStr}T00:00:00Z`);
  const dayOfWeek = date.getUTCDay();

  if (plan.scheduleType === 'weekly') {
    return plan.planDays.filter((d) => d.dayOfWeek === dayOfWeek).map((d) => d.id);
  }

  const ms = date.getTime() - plan.createdAt.getTime();
  const daysSinceStart = Math.max(0, Math.floor(ms / 86_400_000));
  const cycleLength = plan.weeksCount ?? 1;
  const weekIndex = Math.floor(daysSinceStart / 7) % cycleLength;
  const weekNumber = weekIndex + 1;
  return plan.planDays
    .filter((d) => d.dayOfWeek === dayOfWeek && d.weekNumber === weekNumber)
    .map((d) => d.id);
}

export async function runDailyStreakCheck(): Promise<void> {
  const yesterday = getYesterdayUTC();
  const yesterdayDate = new Date(`${yesterday}T00:00:00Z`);
  // Half-open interval [yesterday 00:00, today 00:00) avoids the 1 ms gap
  // that `23:59:59.999Z` would leave (Issue 3).
  const todayDate = new Date(yesterdayDate.getTime() + 86_400_000);

  // Load active plans, most recently updated first so if a user somehow has two
  // active plans we consistently pick the most recently activated one (Issue 4).
  const activePlans = await prisma.workoutPlan.findMany({
    where: { isActive: true, deletedAt: null },
    orderBy: { updatedAt: 'desc' },
    select: {
      id: true,
      userId: true,
      scheduleType: true,
      weeksCount: true,
      createdAt: true,
      planDays: {
        select: { id: true, dayOfWeek: true, weekNumber: true },
      },
    },
  });

  const planByUser = new Map<string, PlanRow>();
  for (const plan of activePlans) {
    if (!planByUser.has(plan.userId)) planByUser.set(plan.userId, plan);
  }

  if (planByUser.size === 0) return;

  // ── Classify users: workout day vs rest day ─────────────────────────────────
  type WorkoutDayUser = { userId: string; planDayIds: string[] };
  const workoutDayUsers: WorkoutDayUser[] = [];
  const restDayUserIds: string[] = [];

  for (const [userId, plan] of planByUser) {
    const ids = getMatchingPlanDayIds(plan, yesterday);
    if (ids.length > 0) {
      workoutDayUsers.push({ userId, planDayIds: ids });
    } else {
      restDayUserIds.push(userId);
    }
  }

  const allUserIds = [...planByUser.keys()];

  // ── Batch reads (Issue 5: replace N+1 per-user queries) ────────────────────
  const [existingHistoryRows, existingStreaks, completedSessions] = await Promise.all([
    // All streak_history entries for yesterday across all users.
    prisma.streakHistory.findMany({
      where: { userId: { in: allUserIds }, date: yesterdayDate },
      select: { userId: true, status: true },
    }),
    // All streak rows for users with active plans.
    prisma.streak.findMany({
      where: { userId: { in: allUserIds } },
      select: { userId: true, currentStreak: true },
    }),
    // All completed sessions for yesterday across every relevant plan day.
    workoutDayUsers.length > 0
      ? prisma.workoutSession.findMany({
          where: {
            planDayId: { in: workoutDayUsers.flatMap((u) => u.planDayIds) },
            status: 'completed',
            // Half-open interval — same boundary fix as above (Issue 3).
            completedAt: { gte: yesterdayDate, lt: todayDate },
          },
          select: { userId: true },
        })
      : Promise.resolve([]),
  ]);

  const historyByUser = new Map(existingHistoryRows.map((r) => [r.userId, r.status]));
  const currentStreakByUser = new Map(existingStreaks.map((r) => [r.userId, r.currentStreak]));
  const completedUserIds = new Set(completedSessions.map((s) => s.userId));

  // ── Determine missed users ──────────────────────────────────────────────────
  const missedUserIds: string[] = [];
  for (const { userId } of workoutDayUsers) {
    // If streak_history already shows 'completed' for yesterday, the session
    // completion handler already ran — skip to avoid overwriting it (Issue 13:
    // guards the race between session completion and this job firing).
    if (historyByUser.get(userId) === 'completed') continue;
    if (!completedUserIds.has(userId)) {
      missedUserIds.push(userId);
    }
  }

  // ── Batch writes: missed ────────────────────────────────────────────────────
  if (missedUserIds.length > 0) {
    const noHistoryYet = missedUserIds.filter((id) => !historyByUser.has(id));
    const hasExistingHistory = missedUserIds.filter((id) => historyByUser.has(id));
    // Users whose currentStreak is already 0 don't need a write (Issue 6).
    const needsStreakReset = missedUserIds.filter(
      (id) => (currentStreakByUser.get(id) ?? 0) > 0,
    );

    await prisma.$transaction([
      // Create 'missed' entries for users who have no history row yet.
      prisma.streakHistory.createMany({
        data: noHistoryYet.map((userId) => ({
          userId,
          date: yesterdayDate,
          status: 'missed' as const,
        })),
        skipDuplicates: true,
      }),
      // Update existing non-completed entries (e.g. 'rest_day' from a prior run).
      prisma.streakHistory.updateMany({
        where: {
          userId: { in: hasExistingHistory },
          date: yesterdayDate,
          status: { not: 'completed' },
        },
        data: { status: 'missed' },
      }),
      // Reset only streaks that are currently > 0 (Issue 6: no redundant writes).
      prisma.streak.updateMany({
        where: { userId: { in: needsStreakReset } },
        data: { currentStreak: 0 },
      }),
    ]);
  }

  // ── Batch writes: rest days ─────────────────────────────────────────────────
  const newRestDayUserIds = restDayUserIds.filter((id) => !historyByUser.has(id));
  if (newRestDayUserIds.length > 0) {
    await prisma.streakHistory.createMany({
      data: newRestDayUserIds.map((userId) => ({
        userId,
        date: yesterdayDate,
        status: 'rest_day' as const,
      })),
      skipDuplicates: true,
    });
  }
}
