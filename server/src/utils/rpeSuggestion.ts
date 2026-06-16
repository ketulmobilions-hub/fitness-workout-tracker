import { prisma } from '../lib/prisma.js';

export interface RpeSuggestionResult {
  suggestedWeight: number;
  basedOn: {
    weightKg: number;
    rpe: number;
    sessionDate: string;
  };
}

/**
 * Given a user's recent training data for an exercise, compute the weight to
 * use to hit [targetRpe] based on the most recent set with weight + RPE logged.
 *
 * Algorithm: each RPE unit ≈ 2.5% of max effort.
 *   suggestedWeight = baseWeight × (1 + (targetRpe − baseRpe) × 0.025)
 *   Rounded to nearest 2.5 kg.
 *
 * Returns null when the user has no completed sets with both weight and RPE
 * logged for this exercise.
 */
export async function rpeToWeightSuggestion(
  userId: string,
  exerciseId: string,
  targetRpe: number,
): Promise<RpeSuggestionResult | null> {
  // Guard against enumeration with invalid exerciseIds — avoids the expensive
  // multi-table join when the exercise doesn't exist.
  const exercise = await prisma.exercise.findUnique({
    where: { id: exerciseId },
    select: { id: true },
  });
  if (!exercise) return null;

  const baseSet = await prisma.setLog.findFirst({
    where: {
      exerciseLog: {
        exerciseId,
        session: { userId, status: 'completed' },
      },
      weightKg: { not: null },
      rpe: { not: null },
    },
    // Most recent session first; within a session, highest set number last
    orderBy: [
      { exerciseLog: { session: { startedAt: 'desc' } } },
      { setNumber: 'desc' },
    ],
    select: {
      weightKg: true,
      rpe: true,
      exerciseLog: {
        select: { session: { select: { startedAt: true } } },
      },
    },
  });

  if (!baseSet) return null;

  const baseWeight = baseSet.weightKg!;
  const baseRpe = baseSet.rpe!;
  const rawSuggestion = baseWeight * (1 + (targetRpe - baseRpe) * 0.025);
  // Epsilon guard to avoid IEEE 754 boundary errors near exact 2.5 kg multiples
  const suggestedWeight = Math.round((rawSuggestion + 1e-9) / 2.5) * 2.5;
  // Guard against out-of-range historical RPE data producing a nonsensical result.
  if (suggestedWeight <= 0) return null;

  return {
    suggestedWeight,
    basedOn: {
      weightKg: baseWeight,
      rpe: baseRpe,
      sessionDate: baseSet.exerciseLog.session.startedAt.toISOString(),
    },
  };
}
