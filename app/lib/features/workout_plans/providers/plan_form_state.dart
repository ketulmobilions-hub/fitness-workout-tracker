import 'package:fitness_domain/fitness_domain.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/errors/app_exception.dart';

part 'plan_form_state.freezed.dart';

/// A draft exercise entry within a plan day, held in-memory during form editing.
///
/// [localId] is a session-scoped unique identifier used to track this exercise
/// across reorders/removes without relying on a mutable list index.
/// [serverId] is null for newly added exercises, non-null in edit mode.
@freezed
abstract class DraftPlanExercise with _$DraftPlanExercise {
  const factory DraftPlanExercise({
    /// Session-unique ID so the targets sheet and drag keys stay stable even
    /// when the exercise is reordered. Generated at add time.
    required String localId,
    String? serverId,
    required String exerciseId,
    required String exerciseName,
    required ExerciseType exerciseType,
    required int sortOrder,
    int? targetSets,
    String? targetReps,
    int? targetDurationSec,
    double? targetDistanceM,
    String? notes,
  }) = _DraftPlanExercise;
}

/// A draft plan day entry, held in-memory during form editing.
/// [serverId] is null for new days, non-null in edit mode.
@freezed
abstract class DraftPlanDay with _$DraftPlanDay {
  const factory DraftPlanDay({
    String? serverId,
    required int dayOfWeek,
    int? weekNumber,
    String? name,
    required int sortOrder,
    @Default([]) List<DraftPlanExercise> exercises,
  }) = _DraftPlanDay;
}

enum PlanFormStep { details, schedule, exercises }

/// Immutable state for the multi-step create/edit workout plan form.
@freezed
abstract class PlanFormState with _$PlanFormState {
  const factory PlanFormState({
    // null = create mode; non-null = edit mode.
    String? editingPlanId,

    // Step 0 — Details
    @Default('') String name,
    @Default('') String description,

    // Step 1 — Schedule
    @Default(ScheduleType.weekly) ScheduleType scheduleType,
    @Default(4) int weeksCount,
    // Indices of selected days of week (0 = Sunday … 6 = Saturday).
    // For weekly plans: directly maps to one DraftPlanDay each.
    // For recurring plans: template applied across all weeks.
    @Default({}) Set<int> selectedDays,

    // Step 2 — Exercises (materialised from schedule when entering this step)
    @Default([]) List<DraftPlanDay> days,

    // Navigation
    @Default(PlanFormStep.details) PlanFormStep currentStep,

    // Transient save state
    @Default(false) bool isSaving,
    AppException? saveError,
    @Default(false) bool saved,
    /// Set alongside [saved] so the UI can navigate to the correct detail page.
    String? savedPlanId,

    // Inline validation errors keyed by field name.
    @Default({}) Map<String, String> fieldErrors,

    /// True while the provider is asynchronously seeding state from the
    /// local Drift cache in edit mode. Guards [goToStep] and [save] from
    /// running before the form is fully populated.
    @Default(false) bool isSeeding,

    /// Tracks the server-assigned plan ID after a successful [createPlan] call
    /// but before all exercises have been added. Allows a retry to skip the
    /// create step and resume exercise-adding if the app is interrupted.
    String? creatingPlanId,

    /// True when [goToStep] detected that advancing to the exercises step
    /// would silently discard exercises from days that no longer fit the new
    /// schedule layout. The UI must show a confirmation dialog, then call
    /// either [confirmScheduleRebuild] or [cancelScheduleRebuild].
    @Default(false) bool pendingScheduleRebuild,
  }) = _PlanFormState;
}
