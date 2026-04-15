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
}
