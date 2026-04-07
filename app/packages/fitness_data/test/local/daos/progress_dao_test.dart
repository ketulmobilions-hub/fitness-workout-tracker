import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:fitness_data/fitness_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProgressDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = db.progressDao;
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

  // Use midnight UTC dates to align with DateStringConverter normalisation.
  final _baseDate = DateTime.utc(2024, 1, 15);

  group('ProgressDao - personal records', () {
    test('upsertPersonalRecord inserts a record', () async {
      await dao.upsertPersonalRecord(
        PersonalRecordsCompanion(
          id: const Value('pr-1'),
          userId: const Value('user-1'),
          exerciseId: const Value('ex-1'),
          recordType: const Value(RecordType.maxWeight),
          value: const Value(150.0),
          achievedAt: Value(_baseDate),
        ),
      );

      final records = await dao.watchRecordsForUser('user-1').first;
      expect(records.length, 1);
      expect(records.first.value, 150.0);
    });

    test('watchRecordsForExercise filters by exercise', () async {
      await db.exerciseDao.upsertExercise(
        ExercisesCompanion(
          id: const Value('ex-2'),
          name: const Value('Bench Press'),
          exerciseType: const Value(ExerciseType.strength),
        ),
      );
      await dao.upsertPersonalRecord(
        PersonalRecordsCompanion(
          id: const Value('pr-1'),
          userId: const Value('user-1'),
          exerciseId: const Value('ex-1'),
          recordType: const Value(RecordType.maxWeight),
          value: const Value(150.0),
          achievedAt: Value(_baseDate),
        ),
      );
      await dao.upsertPersonalRecord(
        PersonalRecordsCompanion(
          id: const Value('pr-2'),
          userId: const Value('user-1'),
          exerciseId: const Value('ex-2'),
          recordType: const Value(RecordType.maxWeight),
          value: const Value(100.0),
          achievedAt: Value(_baseDate),
        ),
      );

      final records =
          await dao.watchRecordsForExercise('user-1', 'ex-1').first;
      expect(records.length, 1);
      expect(records.first.id, 'pr-1');
    });
  });

  group('ProgressDao - streaks', () {
    test('upsertStreak inserts streak', () async {
      await dao.upsertStreak(
        StreaksCompanion(
          id: const Value('streak-1'),
          userId: const Value('user-1'),
          currentStreak: const Value(5),
          longestStreak: const Value(10),
        ),
      );

      final streak = await dao.watchStreak('user-1').first;
      expect(streak, isNotNull);
      expect(streak!.currentStreak, 5);
    });

    test('upsertStreak updates existing streak (conflict on userId)', () async {
      await dao.upsertStreak(
        StreaksCompanion(
          id: const Value('streak-1'),
          userId: const Value('user-1'),
          currentStreak: const Value(5),
          longestStreak: const Value(10),
        ),
      );
      // Simulate server sync with a different id but same userId.
      await dao.upsertStreak(
        StreaksCompanion(
          id: const Value('streak-server'),
          userId: const Value('user-1'),
          currentStreak: const Value(6),
          longestStreak: const Value(10),
        ),
      );

      // Should update, not insert a second row.
      final streak = await dao.watchStreak('user-1').first;
      expect(streak!.currentStreak, 6);
      final all = await db.select(db.streaks).get();
      expect(all.length, 1);
    });

    test('upsertStreak stamps updatedAt when not provided', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await dao.upsertStreak(
        StreaksCompanion(
          id: const Value('streak-1'),
          userId: const Value('user-1'),
          currentStreak: const Value(1),
          longestStreak: const Value(1),
        ),
      );
      final streak = await dao.watchStreak('user-1').first;
      expect(streak!.updatedAt.isAfter(before), isTrue);
    });

    test('watchStreak returns null for unknown user', () async {
      final streak = await dao.watchStreak('unknown').first;
      expect(streak, isNull);
    });
  });

  group('ProgressDao - streak history', () {
    test('upsertStreakHistoryEntry inserts entry', () async {
      await dao.upsertStreakHistoryEntry(
        StreakHistoryCompanion(
          id: const Value('sh-1'),
          userId: const Value('user-1'),
          date: Value(_baseDate),
          status: const Value(StreakDayStatus.completed),
        ),
      );

      final history = await dao.watchStreakHistory('user-1').first;
      expect(history.length, 1);
      expect(history.first.status, StreakDayStatus.completed);
    });

    test('UNIQUE (user_id, date) prevents duplicate entries for same day',
        () async {
      // Insert initial entry for _baseDate.
      await dao.upsertStreakHistoryEntry(
        StreakHistoryCompanion(
          id: const Value('sh-1'),
          userId: const Value('user-1'),
          date: Value(_baseDate),
          status: const Value(StreakDayStatus.completed),
        ),
      );
      // Insert a second entry with a different id but the same (userId, date).
      // Should update rather than insert a duplicate.
      await dao.upsertStreakHistoryEntry(
        StreakHistoryCompanion(
          id: const Value('sh-2'),
          userId: const Value('user-1'),
          date: Value(_baseDate),
          status: const Value(StreakDayStatus.restDay),
        ),
      );

      final history = await dao.watchStreakHistory('user-1').first;
      // Exactly one row: the constraint prevented a duplicate.
      expect(history.length, 1);
      expect(history.first.status, StreakDayStatus.restDay);
    });

    test('DateStringConverter ensures same-day timestamps are treated as equal',
        () async {
      // Two timestamps on 2024-01-15 at different times of day.
      final morning = DateTime.utc(2024, 1, 15, 8, 0);
      final evening = DateTime.utc(2024, 1, 15, 20, 0);

      await dao.upsertStreakHistoryEntry(
        StreakHistoryCompanion(
          id: const Value('sh-1'),
          userId: const Value('user-1'),
          date: Value(morning),
          status: const Value(StreakDayStatus.completed),
        ),
      );
      await dao.upsertStreakHistoryEntry(
        StreakHistoryCompanion(
          id: const Value('sh-2'),
          userId: const Value('user-1'),
          date: Value(evening),
          status: const Value(StreakDayStatus.restDay),
        ),
      );

      // Both share date "2024-01-15" → only one row should exist.
      final history = await dao.watchStreakHistory('user-1').first;
      expect(history.length, 1);
    });

    test('watchStreakHistory since filter works', () async {
      final dates = [
        DateTime.utc(2024, 1, 10),
        DateTime.utc(2024, 1, 15),
        DateTime.utc(2024, 1, 20),
      ];
      for (var i = 0; i < dates.length; i++) {
        await dao.upsertStreakHistoryEntry(
          StreakHistoryCompanion(
            id: Value('sh-$i'),
            userId: const Value('user-1'),
            date: Value(dates[i]),
            status: const Value(StreakDayStatus.completed),
          ),
        );
      }

      final history = await dao
          .watchStreakHistory('user-1', since: DateTime.utc(2024, 1, 14))
          .first;
      expect(history.length, 2);
    });
  });
}
