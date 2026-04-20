import 'package:drift/drift.dart';

import '../app_database.dart';
import '../converters/exercise_type_converter.dart';
import '../tables/exercise_library_tables.dart';

part 'exercise_dao.g.dart';

@DriftAccessor(tables: [Exercises, MuscleGroups, ExerciseMuscleGroups])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.db);

  Stream<List<ExerciseRow>> watchAllExercises() {
    return select(exercises).watch();
  }

  Stream<List<ExerciseRow>> watchExercisesByType(ExerciseType type) {
    return (select(exercises)
          ..where((t) => t.exerciseType.equals(
                const ExerciseTypeConverter().toSql(type),
              )))
        .watch();
  }

  Stream<ExerciseRow?> watchExercise(String id) {
    return (select(exercises)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<ExerciseRow?> getExercise(String id) {
    return (select(exercises)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertExercise(ExercisesCompanion companion) {
    // Stamp updatedAt for local writes; preserve server value when syncing.
    final toWrite = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return into(exercises).insertOnConflictUpdate(toWrite);
  }

  Future<int> deleteExercise(String id) {
    return (delete(exercises)..where((t) => t.id.equals(id))).go();
  }

  Future<List<MuscleGroupRow>> getAllMuscleGroups() {
    return select(muscleGroups).get();
  }

  Future<void> upsertMuscleGroup(MuscleGroupsCompanion companion) {
    return into(muscleGroups).insertOnConflictUpdate(companion);
  }

  Stream<List<MuscleGroupRow>> watchMuscleGroupsForExercise(
      String exerciseId) {
    final query = select(muscleGroups).join([
      innerJoin(
        exerciseMuscleGroups,
        exerciseMuscleGroups.muscleGroupId.equalsExp(muscleGroups.id),
      ),
    ])
      ..where(exerciseMuscleGroups.exerciseId.equals(exerciseId));

    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(muscleGroups)).toList(),
        );
  }

  /// Replaces all muscle-group associations for [exerciseId] in a single
  /// transaction using a batch insert instead of per-row inserts.
  Future<void> setExerciseMuscleGroups(
    String exerciseId,
    List<ExerciseMuscleGroupsCompanion> groups,
  ) {
    return transaction(() async {
      await (delete(exerciseMuscleGroups)
            ..where((t) => t.exerciseId.equals(exerciseId)))
          .go();
      if (groups.isNotEmpty) {
        await batch((b) {
          b.insertAllOnConflictUpdate(exerciseMuscleGroups, groups);
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Filtered streams (used by exerciseListProvider)
  // ---------------------------------------------------------------------------

  /// Returns a reactive stream of exercises filtered by [search], [type],
  /// and/or [muscleGroupName].
  ///
  /// All parameters are optional — omitting them returns all exercises ordered
  /// by name. When [muscleGroupName] is provided the query joins through
  /// [exerciseMuscleGroups] and [muscleGroups]; duplicate rows caused by
  /// multiple matching muscle groups are de-duplicated in Dart.
  Stream<List<ExerciseRow>> watchExercisesFiltered({
    String? search,
    ExerciseType? type,
    String? muscleGroupName,
  }) {
    if (muscleGroupName != null) {
      // JOIN path — exercises → exercise_muscle_groups → muscle_groups
      final query = select(exercises).join([
        innerJoin(
          exerciseMuscleGroups,
          exerciseMuscleGroups.exerciseId.equalsExp(exercises.id),
        ),
        innerJoin(
          muscleGroups,
          muscleGroups.id.equalsExp(exerciseMuscleGroups.muscleGroupId),
        ),
      ]);

      query.where(muscleGroups.name.equals(muscleGroupName));

      if (type != null) {
        query.where(
          exercises.exerciseType
              .equals(const ExerciseTypeConverter().toSql(type)),
        );
      }
      if (search != null && search.isNotEmpty) {
        final pattern = '%${search.toLowerCase()}%';
        query.where(
          exercises.name.lower().like(pattern) |
              exercises.description.lower().like(pattern),
        );
      }
      query.orderBy([OrderingTerm.asc(exercises.name)]);

      return query.watch().map(
            (rows) => rows
                .map((r) => r.readTable(exercises))
                .toSet()
                .toList(), // deduplicate
          );
    }

    // Simple path — no join needed
    final query = select(exercises);
    query.where((t) => const Constant(true));

    if (type != null) {
      query.where(
        (t) => t.exerciseType
            .equals(const ExerciseTypeConverter().toSql(type)),
      );
    }
    if (search != null && search.isNotEmpty) {
      final pattern = '%${search.toLowerCase()}%';
      query.where(
        (t) => t.name.lower().like(pattern) | t.description.lower().like(pattern),
      );
    }
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch();
  }

  // ---------------------------------------------------------------------------
  // Muscle group streams / futures
  // ---------------------------------------------------------------------------

  /// Reactive stream of all muscle groups ordered by region then display name.
  Stream<List<MuscleGroupRow>> watchAllMuscleGroupsStream() {
    return (select(muscleGroups)
          ..orderBy([
            (t) => OrderingTerm.asc(t.bodyRegion),
            (t) => OrderingTerm.asc(t.displayName),
          ]))
        .watch();
  }

  /// Reactive stream of muscle groups for [exerciseId] including the
  /// [ExerciseMuscleGroupRow.isPrimary] flag.
  Stream<List<({MuscleGroupRow muscleGroup, bool isPrimary})>>
      watchMuscleGroupsWithPrimaryForExercise(String exerciseId) {
    final query = select(exerciseMuscleGroups).join([
      innerJoin(
        muscleGroups,
        muscleGroups.id.equalsExp(exerciseMuscleGroups.muscleGroupId),
      ),
    ])
      ..where(exerciseMuscleGroups.exerciseId.equals(exerciseId));

    return query.watch().map(
          (rows) => rows
              .map(
                (r) => (
                  muscleGroup: r.readTable(muscleGroups),
                  isPrimary: r.readTable(exerciseMuscleGroups).isPrimary,
                ),
              )
              .toList(),
        );
  }

  /// **Future** (not a stream) — returns muscle groups with isPrimary flag for
  /// [exerciseId]. Use this inside `asyncMap` to avoid the broadcast-stream
  /// `.first` hang: Drift watch() streams are broadcast; calling `.first`
  /// on them waits for the *next* emission rather than returning the current
  /// value, which hangs indefinitely when the DB is idle.
  Future<List<({MuscleGroupRow muscleGroup, bool isPrimary})>>
      getExerciseMuscleGroupsWithPrimary(String exerciseId) {
    final query = select(exerciseMuscleGroups).join([
      innerJoin(
        muscleGroups,
        muscleGroups.id.equalsExp(exerciseMuscleGroups.muscleGroupId),
      ),
    ])
      ..where(exerciseMuscleGroups.exerciseId.equals(exerciseId));

    return query.get().then(
          (rows) => rows
              .map(
                (r) => (
                  muscleGroup: r.readTable(muscleGroups),
                  isPrimary: r.readTable(exerciseMuscleGroups).isPrimary,
                ),
              )
              .toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Sync helpers
  // ---------------------------------------------------------------------------

  /// Deletes all non-custom (system) exercises whose IDs are NOT in [ids].
  /// Called at the end of a full sync to remove exercises the server has
  /// deleted, preventing zombie rows from accumulating in the local cache.
  Future<void> deleteSystemExercisesNotInSet(Set<String> ids) {
    return (delete(exercises)
          ..where(
            (t) => t.isCustom.equals(false) & t.id.isNotIn(ids),
          ))
        .go();
  }
}
