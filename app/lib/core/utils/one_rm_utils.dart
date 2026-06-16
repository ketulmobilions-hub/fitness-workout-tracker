import 'dart:math' as math;

import '../../features/active_session/providers/active_session_notifier.dart'
    show WorkoutSummary;

double _epley(double weightKg, int reps) {
  if (reps <= 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

double _brzycki(double weightKg, int reps) {
  if (reps <= 1) return weightKg;
  if (reps >= 36) return _epley(weightKg, reps);
  return weightKg * (36 / (37 - reps));
}

double _lombardi(double weightKg, int reps) {
  if (reps <= 1) return weightKg;
  return weightKg * math.pow(reps, 0.1);
}

/// 3-formula average (Epley + Brzycki + Lombardi).
/// For reps ≥ 36, uses Epley + Lombardi only to avoid Brzycki singularity.
/// Returns weight unchanged for singles. Rounded to 2 decimal places.
double estimateOneRepMax(double weightKg, int reps) {
  if (reps <= 1) return (weightKg * 100).round() / 100;
  final avg = reps >= 36
      ? (_epley(weightKg, reps) + _lombardi(weightKg, reps)) / 2
      : (_epley(weightKg, reps) + _brzycki(weightKg, reps) + _lombardi(weightKg, reps)) / 3;
  return (avg * 100).round() / 100;
}

class SessionOneRmResult {
  const SessionOneRmResult({
    required this.exerciseName,
    required this.estimatedOneRepMax,
  });

  final String exerciseName;
  final double estimatedOneRepMax;
}

/// Finds the non-warmup set with the highest estimated 1RM across all exercises
/// in [summary]. Returns null if no qualifying sets exist.
SessionOneRmResult? bestSessionOneRepMax(WorkoutSummary summary) {
  String? bestExercise;
  double? best;
  for (final ex in summary.exerciseData) {
    for (final set in ex.loggedSets) {
      if (set.isWarmup) continue;
      final w = set.weightKg;
      final r = set.reps;
      if (w == null || r == null || w <= 0 || r <= 0 || r > 99) continue;
      final est = estimateOneRepMax(w, r);
      if (best == null || est > best) {
        best = est;
        bestExercise = ex.planExercise.exerciseName;
      }
    }
  }
  if (best == null || bestExercise == null) return null;
  return SessionOneRmResult(
    exerciseName: bestExercise,
    estimatedOneRepMax: best,
  );
}
