import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late WorkoutPlanDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = db.workoutPlanDao;
    // Insert a user required by FK constraints
    await db.userDao.upsertUser(
      UsersCompanion(
        id: const Value('user-1'),
        email: const Value('test@example.com'),
        displayName: const Value('Test User'),
        authProvider: const Value(AuthProvider.emailPassword),
      ),
    );
  });

  tearDown(() async => db.close());

  WorkoutPlansCompanion _plan({
    String id = 'plan-1',
    String name = 'My Plan',
    ScheduleType schedule = ScheduleType.weekly,
  }) {
    return WorkoutPlansCompanion(
      id: Value(id),
      userId: const Value('user-1'),
      name: Value(name),
      scheduleType: Value(schedule),
    );
  }

  PlanDaysCompanion _day({
    String id = 'day-1',
    String planId = 'plan-1',
    int dayOfWeek = 1,
    int sortOrder = 0,
  }) {
    return PlanDaysCompanion(
      id: Value(id),
      planId: Value(planId),
      dayOfWeek: Value(dayOfWeek),
      weekNumber: const Value(1),
      sortOrder: Value(sortOrder),
    );
  }

  group('WorkoutPlanDao - plans', () {
    test('upsertPlan inserts a plan', () async {
      await dao.upsertPlan(_plan());

      final plans = await dao.watchPlansForUser('user-1').first;
      expect(plans.length, 1);
      expect(plans.first.name, 'My Plan');
    });

    test('upsertPlan stamps updatedAt when not provided', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await dao.upsertPlan(_plan());
      final plans = await dao.watchPlansForUser('user-1').first;
      expect(plans.first.updatedAt.isAfter(before), isTrue);
    });

    test('upsertPlan updates existing plan', () async {
      await dao.upsertPlan(_plan());
      await dao.upsertPlan(_plan().copyWith(name: const Value('Updated Plan')));

      final plans = await dao.watchPlansForUser('user-1').first;
      expect(plans.length, 1);
      expect(plans.first.name, 'Updated Plan');
    });

    test('deletePlan removes the plan', () async {
      await dao.upsertPlan(_plan());
      await dao.deletePlan('plan-1');

      final plans = await dao.watchPlansForUser('user-1').first;
      expect(plans, isEmpty);
    });

    test('watchPlansForUser only returns plans for that user', () async {
      await db.userDao.upsertUser(
        UsersCompanion(
          id: const Value('user-2'),
          email: const Value('other@example.com'),
          displayName: const Value('Other'),
          authProvider: const Value(AuthProvider.emailPassword),
        ),
      );
      await dao.upsertPlan(_plan(id: 'plan-1'));
      await dao.upsertPlan(
        WorkoutPlansCompanion(
          id: const Value('plan-2'),
          userId: const Value('user-2'),
          name: const Value('Other Plan'),
          scheduleType: const Value(ScheduleType.weekly),
        ),
      );

      final plans = await dao.watchPlansForUser('user-1').first;
      expect(plans.length, 1);
      expect(plans.first.id, 'plan-1');
    });
  });

  group('WorkoutPlanDao - days', () {
    setUp(() async => dao.upsertPlan(_plan()));

    test('upsertPlanDay inserts a day', () async {
      await dao.upsertPlanDay(_day());

      final days = await dao.watchDaysForPlan('plan-1').first;
      expect(days.length, 1);
      expect(days.first.dayOfWeek, 1);
    });

    test('deletePlanDay removes the day', () async {
      await dao.upsertPlanDay(_day());
      await dao.deletePlanDay('day-1');

      final days = await dao.watchDaysForPlan('plan-1').first;
      expect(days, isEmpty);
    });
  });

  group('WorkoutPlanDao - plan day exercises', () {
    late ExercisesCompanion exercise;

    setUp(() async {
      await dao.upsertPlan(_plan());
      await dao.upsertPlanDay(_day());
      exercise = ExercisesCompanion(
        id: const Value('ex-1'),
        name: const Value('Squat'),
        exerciseType: const Value(ExerciseType.strength),
      );
      await db.exerciseDao.upsertExercise(exercise);
    });

    test('upsertPlanDayExercise inserts entry', () async {
      await dao.upsertPlanDayExercise(
        PlanDayExercisesCompanion(
          id: const Value('pde-1'),
          planDayId: const Value('day-1'),
          exerciseId: const Value('ex-1'),
          sortOrder: const Value(0),
        ),
      );

      final entries = await dao.watchExercisesForPlanDay('day-1').first;
      expect(entries.length, 1);
    });

    test('reorderPlanDayExercises updates sort order', () async {
      for (var i = 0; i < 3; i++) {
        await dao.upsertPlanDayExercise(
          PlanDayExercisesCompanion(
            id: Value('pde-$i'),
            planDayId: const Value('day-1'),
            exerciseId: const Value('ex-1'),
            sortOrder: Value(i),
          ),
        );
      }

      await dao.reorderPlanDayExercises('day-1', ['pde-2', 'pde-0', 'pde-1']);

      final entries = await dao.watchExercisesForPlanDay('day-1').first;
      expect(entries[0].id, 'pde-2');
      expect(entries[1].id, 'pde-0');
      expect(entries[2].id, 'pde-1');
    });

    test('reorderPlanDayExercises ignores IDs from a different planDayId',
        () async {
      // Create a second plan day with its own exercise entry.
      await dao.upsertPlanDay(
        PlanDaysCompanion(
          id: const Value('day-2'),
          planId: const Value('plan-1'),
          dayOfWeek: const Value(2),
          weekNumber: const Value(1),
          sortOrder: const Value(1),
        ),
      );
      await dao.upsertPlanDayExercise(
        PlanDayExercisesCompanion(
          id: const Value('pde-other'),
          planDayId: const Value('day-2'),
          exerciseId: const Value('ex-1'),
          sortOrder: const Value(0),
        ),
      );

      // Reorder day-1 but accidentally include an ID from day-2.
      await dao.upsertPlanDayExercise(
        PlanDayExercisesCompanion(
          id: const Value('pde-0'),
          planDayId: const Value('day-1'),
          exerciseId: const Value('ex-1'),
          sortOrder: const Value(0),
        ),
      );
      await dao.reorderPlanDayExercises(
          'day-1', ['pde-0', 'pde-other']);

      // pde-other belongs to day-2 — its sortOrder must NOT be changed.
      final day2Entries =
          await dao.watchExercisesForPlanDay('day-2').first;
      expect(day2Entries.first.sortOrder, 0);
    });
  });
}
