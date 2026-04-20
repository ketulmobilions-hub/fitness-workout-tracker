import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/exercise_library_tables.dart';
import '../tables/workout_plan_tables.dart';

part 'workout_plan_dao.g.dart';

@DriftAccessor(tables: [WorkoutPlans, PlanDays, PlanDayExercises, Exercises])
class WorkoutPlanDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutPlanDaoMixin {
  WorkoutPlanDao(super.db);

  // ---------------------------------------------------------------------------
  // Plans
  // ---------------------------------------------------------------------------

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

  /// One-shot query for a single plan. Use instead of [watchPlan] when a
  /// Future is required (e.g. offline fallback in a repository write path).
  Future<WorkoutPlanRow?> getPlan(String id) {
    return (select(workoutPlans)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
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

  // ---------------------------------------------------------------------------
  // Plan days — reactive streams
  // ---------------------------------------------------------------------------

  Stream<List<PlanDayRow>> watchDaysForPlan(String planId) {
    return (select(planDays)
          ..where((t) => t.planId.equals(planId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.weekNumber),
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // Plan days — one-shot Future queries (use these inside asyncMap)
  // ---------------------------------------------------------------------------

  /// One-shot query for days belonging to [planId], ordered by week then sort.
  /// Use this (not the watch variant) inside [asyncMap] callbacks to avoid
  /// hanging on an empty table — watch streams only emit on writes, not on
  /// initial subscribe when the table is empty.
  Future<List<PlanDayRow>> getDaysForPlan(String planId) {
    return (select(planDays)
          ..where((t) => t.planId.equals(planId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.weekNumber),
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .get();
  }

  Future<void> upsertPlanDay(PlanDaysCompanion companion) {
    return into(planDays).insertOnConflictUpdate(companion);
  }

  Future<int> deletePlanDay(String id) {
    return (delete(planDays)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes all days belonging to [planId] whose IDs are NOT in [keepIds].
  /// Called during sync to remove server-deleted days from the local cache.
  Future<void> deletePlanDaysNotInSet(String planId, Set<String> keepIds) {
    return (delete(planDays)
          ..where(
            (t) =>
                t.planId.equals(planId) &
                t.id.isNotIn(keepIds.isEmpty ? [''] : keepIds),
          ))
        .go();
  }

  // ---------------------------------------------------------------------------
  // Plan day exercises — reactive streams
  // ---------------------------------------------------------------------------

  Stream<List<PlanDayExerciseRow>> watchExercisesForPlanDay(
      String planDayId) {
    return (select(planDayExercises)
          ..where((t) => t.planDayId.equals(planDayId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Returns a reactive stream of (PlanDayExerciseRow, ExerciseRow) pairs for
  /// [planDayId], ordered by sort_order. Use this for real-time UI updates.
  ///
  /// Read results with:
  ///   row.readTable(planDayExercises)  → PlanDayExerciseRow
  ///   row.readTable(exercises)          → ExerciseRow
  Stream<List<TypedResult>> watchExercisesForPlanDayWithDetails(
      String planDayId) {
    final query = (select(planDayExercises)
          ..where((e) => e.planDayId.equals(planDayId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .join([
      innerJoin(exercises, exercises.id.equalsExp(planDayExercises.exerciseId)),
    ]);
    return query.watch();
  }

  // ---------------------------------------------------------------------------
  // Plan day exercises — one-shot Future queries (use these inside asyncMap)
  // ---------------------------------------------------------------------------

  /// One-shot query for exercises in [planDayId] joined with their exercise
  /// details, ordered by sort_order.
  /// Use this (not the watch variant) inside [asyncMap] callbacks.
  Future<List<TypedResult>> getExercisesForPlanDayWithDetails(
      String planDayId) {
    final query = (select(planDayExercises)
          ..where((e) => e.planDayId.equals(planDayId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .join([
      innerJoin(exercises, exercises.id.equalsExp(planDayExercises.exerciseId)),
    ]);
    return query.get();
  }

  /// One-shot query for a single plan day exercise row.
  /// Used in offline fallbacks to resolve exerciseId/exerciseName/exerciseType.
  Future<PlanDayExerciseRow?> getPlanDayExercise(String id) {
    return (select(planDayExercises)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// One-shot lookup of an exercise from the shared exercise library.
  /// Used in offline fallbacks to resolve exercise name and type.
  Future<ExerciseRow?> getExerciseById(String id) {
    return (select(exercises)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertPlanDayExercise(PlanDayExercisesCompanion companion) {
    return into(planDayExercises).insertOnConflictUpdate(companion);
  }

  Future<int> deletePlanDayExercise(String id) {
    return (delete(planDayExercises)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes all exercises in [planDayId] whose IDs are NOT in [keepIds].
  /// Called during sync to remove server-deleted exercises from the local cache.
  Future<void> deletePlanDayExercisesNotInSet(
      String planDayId, Set<String> keepIds) {
    return (delete(planDayExercises)
          ..where(
            (t) =>
                t.planDayId.equals(planDayId) &
                t.id.isNotIn(keepIds.isEmpty ? [''] : keepIds),
          ))
        .go();
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
