import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:fitness_data/fitness_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ExerciseDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = db.exerciseDao;
  });

  tearDown(() async => db.close());

  ExercisesCompanion _exercise({
    String id = 'ex-1',
    String name = 'Squat',
    ExerciseType type = ExerciseType.strength,
  }) {
    return ExercisesCompanion(
      id: Value(id),
      name: Value(name),
      exerciseType: Value(type),
    );
  }

  MuscleGroupsCompanion _muscleGroup({
    String id = 'mg-1',
    String name = 'quadriceps',
    String displayName = 'Quadriceps',
    String bodyRegion = 'legs',
  }) {
    return MuscleGroupsCompanion(
      id: Value(id),
      name: Value(name),
      displayName: Value(displayName),
      bodyRegion: Value(bodyRegion),
    );
  }

  group('ExerciseDao', () {
    test('upsertExercise inserts and retrieves', () async {
      await dao.upsertExercise(_exercise());

      final result = await dao.getExercise('ex-1');
      expect(result, isNotNull);
      expect(result!.name, 'Squat');
    });

    test('upsertExercise stamps updatedAt when not provided', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await dao.upsertExercise(_exercise());
      final result = await dao.getExercise('ex-1');
      expect(result!.updatedAt.isAfter(before), isTrue);
    });

    test('upsertExercise updates existing', () async {
      await dao.upsertExercise(_exercise());
      await dao.upsertExercise(
        _exercise().copyWith(name: const Value('Back Squat')),
      );

      final result = await dao.getExercise('ex-1');
      expect(result!.name, 'Back Squat');
    });

    test('getExercise returns null for unknown id', () async {
      expect(await dao.getExercise('nonexistent'), isNull);
    });

    test('deleteExercise removes the exercise', () async {
      await dao.upsertExercise(_exercise());
      await dao.deleteExercise('ex-1');
      expect(await dao.getExercise('ex-1'), isNull);
    });

    test('watchAllExercises emits all exercises', () async {
      await dao.upsertExercise(_exercise(id: 'ex-1', name: 'Squat'));
      await dao.upsertExercise(_exercise(id: 'ex-2', name: 'Bench Press'));

      final results = await dao.watchAllExercises().first;
      expect(results.length, 2);
    });

    test('watchExercisesByType filters correctly', () async {
      await dao.upsertExercise(
          _exercise(id: 'ex-1', name: 'Squat', type: ExerciseType.strength));
      await dao.upsertExercise(
          _exercise(id: 'ex-2', name: 'Run', type: ExerciseType.cardio));

      final strength = await dao.watchExercisesByType(ExerciseType.strength).first;
      expect(strength.length, 1);
      expect(strength.first.name, 'Squat');
    });

    test('upsertMuscleGroup and getAllMuscleGroups', () async {
      await dao.upsertMuscleGroup(_muscleGroup());
      final groups = await dao.getAllMuscleGroups();
      expect(groups.length, 1);
      expect(groups.first.displayName, 'Quadriceps');
    });

    test('setExerciseMuscleGroups inserts junction rows', () async {
      await dao.upsertExercise(_exercise());
      await dao.upsertMuscleGroup(_muscleGroup());

      await dao.setExerciseMuscleGroups('ex-1', [
        ExerciseMuscleGroupsCompanion(
          exerciseId: const Value('ex-1'),
          muscleGroupId: const Value('mg-1'),
          isPrimary: const Value(true),
        ),
      ]);

      final groups = await dao.watchMuscleGroupsForExercise('ex-1').first;
      expect(groups.length, 1);
      expect(groups.first.name, 'quadriceps');
    });

    test('setExerciseMuscleGroups replaces existing groups', () async {
      await dao.upsertExercise(_exercise());
      await dao.upsertMuscleGroup(_muscleGroup(id: 'mg-1', name: 'quads'));
      await dao.upsertMuscleGroup(
          _muscleGroup(id: 'mg-2', name: 'glutes', displayName: 'Glutes'));

      // Insert mg-1
      await dao.setExerciseMuscleGroups('ex-1', [
        ExerciseMuscleGroupsCompanion(
          exerciseId: const Value('ex-1'),
          muscleGroupId: const Value('mg-1'),
        ),
      ]);

      // Replace with mg-2
      await dao.setExerciseMuscleGroups('ex-1', [
        ExerciseMuscleGroupsCompanion(
          exerciseId: const Value('ex-1'),
          muscleGroupId: const Value('mg-2'),
        ),
      ]);

      final groups = await dao.watchMuscleGroupsForExercise('ex-1').first;
      expect(groups.length, 1);
      expect(groups.first.name, 'glutes');
    });
  });
}
