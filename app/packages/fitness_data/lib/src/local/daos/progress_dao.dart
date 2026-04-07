import 'package:drift/drift.dart';

import '../app_database.dart';
import '../converters/date_string_converter.dart';
import '../tables/progress_tables.dart';

part 'progress_dao.g.dart';

@DriftAccessor(tables: [PersonalRecords, Streaks, StreakHistory])
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  // Personal records

  Stream<List<PersonalRecordRow>> watchRecordsForUser(String userId) {
    return (select(personalRecords)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.achievedAt)]))
        .watch();
  }

  Stream<List<PersonalRecordRow>> watchRecordsForExercise(
    String userId,
    String exerciseId,
  ) {
    return (select(personalRecords)
          ..where((t) =>
              t.userId.equals(userId) & t.exerciseId.equals(exerciseId))
          ..orderBy([(t) => OrderingTerm.desc(t.achievedAt)]))
        .watch();
  }

  Future<void> upsertPersonalRecord(PersonalRecordsCompanion companion) {
    return into(personalRecords).insertOnConflictUpdate(companion);
  }

  // Streaks

  Stream<StreakRow?> watchStreak(String userId) {
    return (select(streaks)..where((t) => t.userId.equals(userId)))
        .watchSingleOrNull();
  }

  /// Upserts a streak row, conflicting on [userId] rather than the surrogate
  /// PK. This ensures a server-generated row (with a different id) merges
  /// correctly with a locally-created row instead of inserting a duplicate
  /// that would then violate the UNIQUE (user_id) constraint.
  Future<void> upsertStreak(StreaksCompanion companion) {
    // Stamp updatedAt for local writes; preserve server value when syncing.
    final toWrite = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return into(streaks).insert(
      toWrite,
      onConflict: DoUpdate(
        (_) => toWrite,
        target: [streaks.userId],
      ),
    );
  }

  // Streak history

  Stream<List<StreakHistoryRow>> watchStreakHistory(
    String userId, {
    DateTime? since,
  }) {
    return (select(streakHistory)
          ..where((t) {
            final userFilter = t.userId.equals(userId);
            if (since != null) {
              // Compare date strings lexicographically (YYYY-MM-DD sorts correctly)
              final sinceStr = const DateStringConverter().toSql(since);
              return userFilter & t.date.isBiggerOrEqualValue(sinceStr);
            }
            return userFilter;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Upserts a streak history entry, conflicting on the UNIQUE (user_id, date)
  /// constraint to ensure at most one entry per calendar day per user.
  Future<void> upsertStreakHistoryEntry(StreakHistoryCompanion companion) {
    return into(streakHistory).insert(
      companion,
      onConflict: DoUpdate(
        (_) => companion,
        target: [streakHistory.userId, streakHistory.date],
      ),
    );
  }
}
