import 'schedule_type.dart';
import 'workout_plan.dart';

abstract class WorkoutPlanRepository {
  /// Stream of the current user's plans (metadata only — no days/exercises).
  /// Used by the plan list screen.
  Stream<List<WorkoutPlan>> watchPlans();

  /// Stream of a single plan with its days and exercises fully populated.
  /// Emits null when no plan with [id] exists in the local cache.
  Stream<WorkoutPlan?> watchPlan(String id);

  /// Fetches the plan list from the API and upserts plan rows into the local
  /// Drift database. Does NOT fetch or sync days/exercises.
  Future<void> syncPlans();

  /// Fetches a single plan's full detail (days + exercises) from the API and
  /// upserts all rows into the local Drift database in a single transaction.
  Future<void> syncPlanDetail(String id);

  // -------------------------------------------------------------------------
  // Write — plan lifecycle
  // -------------------------------------------------------------------------

  /// Creates a new plan on the server, persists it to the local cache, and
  /// returns the created [WorkoutPlan] with server-assigned IDs.
  ///
  /// [initialDays] are the day stubs (no exercises) to create along with the
  /// plan. Exercise population is done separately via [addExerciseToDay].
  Future<WorkoutPlan> createPlan({
    required String name,
    String? description,
    required ScheduleType scheduleType,
    int? weeksCount,
    List<PlanDay>? initialDays,
  });

  /// Updates plan metadata fields. Only fields that are non-null are sent to
  /// the server. Returns the updated [WorkoutPlan].
  Future<WorkoutPlan> updatePlan({
    required String id,
    String? name,
    String? description,
    ScheduleType? scheduleType,
    int? weeksCount,
    bool? isActive,
  });

  /// Soft-deletes the plan on the server and removes all related rows from the
  /// local Drift database.
  Future<void> deletePlan(String id);

  // -------------------------------------------------------------------------
  // Write — exercises within a plan day
  // -------------------------------------------------------------------------

  /// Adds a single exercise to the specified plan day. Returns the created
  /// [PlanDayExercise] with its server-assigned ID.
  Future<PlanDayExercise> addExerciseToDay({
    required String planId,
    required String planDayId,
    required String exerciseId,
    required int sortOrder,
    int? targetSets,
    String? targetReps,
    int? targetDurationSec,
    double? targetDistanceM,
    String? notes,
  });

  /// Updates the target fields of an existing plan-day exercise. Returns the
  /// updated [PlanDayExercise].
  Future<PlanDayExercise> updatePlanExercise({
    required String planId,
    required String planDayExerciseId,
    int? sortOrder,
    int? targetSets,
    String? targetReps,
    int? targetDurationSec,
    double? targetDistanceM,
    String? notes,
  });

  /// Removes a single exercise from a plan day on the server and from the
  /// local Drift cache.
  Future<void> deletePlanExercise({
    required String planId,
    required String planDayExerciseId,
  });

  /// Persists a new sort order for all exercises in one plan day. [orderedIds]
  /// must contain every exercise ID belonging to that day in the desired order.
  Future<void> reorderDayExercises({
    required String planId,
    required String planDayId,
    required List<String> orderedExerciseIds,
  });
}
