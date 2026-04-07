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
}
