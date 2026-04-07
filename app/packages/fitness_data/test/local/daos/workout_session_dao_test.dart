import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:fitness_data/fitness_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late WorkoutSessionDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = db.workoutSessionDao;
    await db.userDao.upsertUser(
      UsersCompanion(
        id: const Value('user-1'),
        email: const Value('test@example.com'),
        displayName: const Value('Test User'),
        authProvider: const Value(AuthProvider.emailPassword),
      ),
    );
    await db.exerciseDao.upsertExercise(
      ExercisesCompanion(
        id: const Value('ex-1'),
        name: const Value('Squat'),
        exerciseType: const Value(ExerciseType.strength),
      ),
    );
  });

  tearDown(() async => db.close());

  final _now = DateTime(2024, 1, 1, 10);

  WorkoutSessionsCompanion _session({
    String id = 'sess-1',
    SessionStatus status = SessionStatus.inProgress,
  }) {
    return WorkoutSessionsCompanion(
      id: Value(id),
      userId: const Value('user-1'),
      startedAt: Value(_now),
      status: Value(status),
    );
  }

  group('WorkoutSessionDao - sessions', () {
    test('upsertSession inserts and retrieves', () async {
      await dao.upsertSession(_session());

      final sessions = await dao.watchSessionsForUser('user-1').first;
      expect(sessions.length, 1);
    });

    test('upsertSession stamps updatedAt when not provided', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await dao.upsertSession(_session());
      final sessions = await dao.watchSessionsForUser('user-1').first;
      expect(sessions.first.updatedAt.isAfter(before), isTrue);
    });

    test('deleteSession removes session', () async {
      await dao.upsertSession(_session());
      await dao.deleteSession('sess-1');

      final sessions = await dao.watchSessionsForUser('user-1').first;
      expect(sessions, isEmpty);
    });

    test('watchActiveSession returns in-progress session', () async {
      await dao.upsertSession(_session(status: SessionStatus.inProgress));

      final active = await dao.watchActiveSession('user-1').first;
      expect(active, isNotNull);
      expect(active!.id, 'sess-1');
    });

    test('watchActiveSession returns null when no active session', () async {
      await dao.upsertSession(_session(status: SessionStatus.completed));

      final active = await dao.watchActiveSession('user-1').first;
      expect(active, isNull);
    });

    test(
        'watchActiveSession does NOT throw when two in-progress sessions exist '
        '(guards against sync race conditions)', () async {
      // Insert two in-progress sessions — this can happen when out-of-order
      // sync pushes a second session before the first is marked complete.
      await dao.upsertSession(_session(id: 'sess-1'));
      await dao.upsertSession(_session(id: 'sess-2'));

      // Must return one session (the first) without throwing StateError.
      expect(
        () async => dao.watchActiveSession('user-1').first,
        returnsNormally,
      );
      final active = await dao.watchActiveSession('user-1').first;
      expect(active, isNotNull);
    });

    test('upsertSession updates status', () async {
      await dao.upsertSession(_session());
      await dao.upsertSession(
        _session().copyWith(status: const Value(SessionStatus.completed)),
      );

      final active = await dao.watchActiveSession('user-1').first;
      expect(active, isNull);
    });
  });

  group('WorkoutSessionDao - exercise logs', () {
    setUp(() async => dao.upsertSession(_session()));

    test('upsertExerciseLog inserts log', () async {
      await dao.upsertExerciseLog(
        ExerciseLogsCompanion(
          id: const Value('log-1'),
          sessionId: const Value('sess-1'),
          exerciseId: const Value('ex-1'),
          sortOrder: const Value(0),
        ),
      );

      final logs = await dao.watchLogsForSession('sess-1').first;
      expect(logs.length, 1);
    });

    test('deleteExerciseLog removes log', () async {
      await dao.upsertExerciseLog(
        ExerciseLogsCompanion(
          id: const Value('log-1'),
          sessionId: const Value('sess-1'),
          exerciseId: const Value('ex-1'),
          sortOrder: const Value(0),
        ),
      );
      await dao.deleteExerciseLog('log-1');

      final logs = await dao.watchLogsForSession('sess-1').first;
      expect(logs, isEmpty);
    });
  });

  group('WorkoutSessionDao - set logs', () {
    setUp(() async {
      await dao.upsertSession(_session());
      await dao.upsertExerciseLog(
        ExerciseLogsCompanion(
          id: const Value('log-1'),
          sessionId: const Value('sess-1'),
          exerciseId: const Value('ex-1'),
          sortOrder: const Value(0),
        ),
      );
    });

    test('upsertSetLog inserts set', () async {
      await dao.upsertSetLog(
        SetLogsCompanion(
          id: const Value('set-1'),
          exerciseLogId: const Value('log-1'),
          setNumber: const Value(1),
          reps: const Value(10),
          weightKg: const Value(100.0),
        ),
      );

      final sets = await dao.watchSetsForExerciseLog('log-1').first;
      expect(sets.length, 1);
      expect(sets.first.reps, 10);
      expect(sets.first.weightKg, 100.0);
    });

    test('deleteSetLog removes set', () async {
      await dao.upsertSetLog(
        SetLogsCompanion(
          id: const Value('set-1'),
          exerciseLogId: const Value('log-1'),
          setNumber: const Value(1),
        ),
      );
      await dao.deleteSetLog('set-1');

      final sets = await dao.watchSetsForExerciseLog('log-1').first;
      expect(sets, isEmpty);
    });

    test('watchSetsForExerciseLog orders by setNumber', () async {
      for (final n in [3, 1, 2]) {
        await dao.upsertSetLog(
          SetLogsCompanion(
            id: Value('set-$n'),
            exerciseLogId: const Value('log-1'),
            setNumber: Value(n),
          ),
        );
      }

      final sets = await dao.watchSetsForExerciseLog('log-1').first;
      expect(sets.map((s) => s.setNumber).toList(), [1, 2, 3]);
    });
  });
}
