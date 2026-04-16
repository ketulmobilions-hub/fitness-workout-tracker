import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_session_summary.freezed.dart';

/// Lightweight summary of a completed workout session — used in history lists.
@freezed
abstract class WorkoutSessionSummary with _$WorkoutSessionSummary {
  const factory WorkoutSessionSummary({
    required String id,
    required DateTime startedAt,
    required DateTime completedAt,
    required int durationSec,
    String? planId,
    /// Human-readable plan name resolved at the repository layer so the
    /// presentation layer does not need to watch the full plan list.
    String? planName,
    required int exerciseCount,
    required int totalSets,
    /// Sum of (reps × weightKg) for all non-warmup strength sets.
    /// Zero for cardio-only sessions.
    required double totalVolumeKg,
  }) = _WorkoutSessionSummary;
}
