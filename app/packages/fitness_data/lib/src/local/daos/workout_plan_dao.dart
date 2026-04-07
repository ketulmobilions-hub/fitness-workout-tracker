import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/workout_plan_tables.dart';

part 'workout_plan_dao.g.dart';

@DriftAccessor(tables: [WorkoutPlans, PlanDays, PlanDayExercises])
class WorkoutPlanDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutPlanDaoMixin {
  WorkoutPlanDao(super.db);

  // Plans

  Stream<List<WorkoutPlanRow>> watchPlansForUser(String userId) {
    return (select(workoutPlans)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Stream<WorkoutPlanRow?> watchPlan(String id) {
    return (select(workoutPlans)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<void> upsertPlan(WorkoutPlansCompanion companion) {
    // Stamp updatedAt for local writes; preserve server value when syncing.
    final toWrite = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return into(workoutPlans).insertOnConflictUpdate(toWrite);
  }

  Future<int> deletePlan(String id) {
    return (delete(workoutPlans)..where((t) => t.id.equals(id))).go();
  }

  // Plan days

  Stream<List<PlanDayRow>> watchDaysForPlan(String planId) {
    return (select(planDays)
          ..where((t) => t.planId.equals(planId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.weekNumber),
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .watch();
  }

  Future<void> upsertPlanDay(PlanDaysCompanion companion) {
    return into(planDays).insertOnConflictUpdate(companion);
  }

  Future<int> deletePlanDay(String id) {
    return (delete(planDays)..where((t) => t.id.equals(id))).go();
  }

  // Plan day exercises

  Stream<List<PlanDayExerciseRow>> watchExercisesForPlanDay(
      String planDayId) {
    return (select(planDayExercises)
          ..where((t) => t.planDayId.equals(planDayId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<void> upsertPlanDayExercise(PlanDayExercisesCompanion companion) {
    return into(planDayExercises).insertOnConflictUpdate(companion);
  }

  Future<int> deletePlanDayExercise(String id) {
    return (delete(planDayExercises)..where((t) => t.id.equals(id))).go();
  }

  /// Updates [sortOrder] for each entry in [orderedIds] in position order.
  ///
  /// [orderedIds] must all belong to [planDayId]. The where clause
  /// `planDayId = ? AND id = ?` ensures a stale-state bug (wrong day's IDs
  /// passed by the UI) silently no-ops rather than corrupting another day's
  /// sort order.
  Future<void> reorderPlanDayExercises(
    String planDayId,
    List<String> orderedIds,
  ) {
    return transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(planDayExercises)
              ..where((t) =>
                  t.id.equals(orderedIds[i]) &
                  t.planDayId.equals(planDayId)))
            .write(PlanDayExercisesCompanion(sortOrder: Value(i)));
      }
    });
  }
}
