import 'package:freezed_annotation/freezed_annotation.dart';

import '../exercises/exercise_type.dart';
import 'schedule_type.dart';

part 'workout_plan.freezed.dart';

@freezed
abstract class WorkoutPlan with _$WorkoutPlan {
  const factory WorkoutPlan({
    required String id,
    required String name,
    String? description,
    required bool isActive,
    required ScheduleType scheduleType,
    int? weeksCount,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default([]) List<PlanDay> days,
  }) = _WorkoutPlan;
}

@freezed
abstract class PlanDay with _$PlanDay {
  const factory PlanDay({
    required String id,
    required int dayOfWeek,
    /// Null for weekly (single-week) plans where a week number is meaningless.
    /// For recurring multi-week plans this is 1-based (1 = first week).
    int? weekNumber,
    String? name,
    required int sortOrder,
    @Default([]) List<PlanDayExercise> exercises,
  }) = _PlanDay;
}

@freezed
abstract class PlanDayExercise with _$PlanDayExercise {
  const factory PlanDayExercise({
    required String id,
    required String exerciseId,
    required String exerciseName,
    required ExerciseType exerciseType,
    required int sortOrder,
    int? targetSets,
    String? targetReps,
    int? targetDurationSec,
    double? targetDistanceM,
    String? notes,
  }) = _PlanDayExercise;
}
