export function epley(weightKg: number, reps: number): number {
  if (reps <= 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

export function brzycki(weightKg: number, reps: number): number {
  if (reps <= 1) return weightKg;
  // Denominator (37 - reps) → 1 at reps=36, producing a near-infinite result.
  // Fall back to Epley for reps ≥ 36 to avoid the singularity.
  if (reps >= 36) return epley(weightKg, reps);
  return weightKg * (36 / (37 - reps));
}

export function lombardi(weightKg: number, reps: number): number {
  if (reps <= 1) return weightKg;
  return weightKg * Math.pow(reps, 0.1);
}

/**
 * Weighted average of Epley, Brzycki, and Lombardi.
 * For reps ≥ 36, Brzycki is unreliable (near-singularity) so only Epley and
 * Lombardi are averaged — avoiding the double-Epley bias that would otherwise
 * result from Brzycki's fallback.
 * Returns the weight directly for singles. Rounded to 2 decimal places.
 */
export function estimateOneRepMax(weightKg: number, reps: number): number {
  if (reps <= 1) return Math.round(weightKg * 100) / 100;
  const avg =
    reps >= 36
      ? (epley(weightKg, reps) + lombardi(weightKg, reps)) / 2
      : (epley(weightKg, reps) + brzycki(weightKg, reps) + lombardi(weightKg, reps)) / 3;
  return Math.round(avg * 100) / 100;
}
