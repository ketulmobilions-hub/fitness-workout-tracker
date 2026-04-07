import 'package:drift/drift.dart';

import '../app_database.dart';
import '../converters/session_status_converter.dart';
import '../tables/workout_session_tables.dart';

part 'workout_session_dao.g.dart';

@DriftAccessor(tables: [WorkoutSessions, ExerciseLogs, SetLogs])
class WorkoutSessionDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutSessionDaoMixin {
  WorkoutSessionDao(super.db);

  // Sessions

  Stream<List<WorkoutSessionRow>> watchSessionsForUser(String userId) {
    return (select(workoutSessions)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  Stream<WorkoutSessionRow?> watchSession(String id) {
    return (select(workoutSessions)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Returns the current in-progress session for [userId], or null if none.
  ///
  /// Uses `limit(1)` + `.watch().map(firstOrNull)` instead of
  /// `watchSingleOrNull()` to avoid a [StateError] if two in-progress sessions
  /// exist simultaneously (e.g., due to an out-of-order sync).
  Stream<WorkoutSessionRow?> watchActiveSession(String userId) {
    return (select(workoutSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.status.equals(
                const SessionStatusConverter()
                    .toSql(SessionStatus.inProgress),
              ))
          ..limit(1))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<void> upsertSession(WorkoutSessionsCompanion companion) {
    // Always stamp updatedAt so the sync engine's last-write-wins logic
    // picks up local mutations.
    final toWrite = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return into(workoutSessions).insertOnConflictUpdate(toWrite);
  }

  Future<int> deleteSession(String id) {
    return (delete(workoutSessions)..where((t) => t.id.equals(id))).go();
  }

  // Exercise logs

  Stream<List<ExerciseLogRow>> watchLogsForSession(String sessionId) {
    return (select(exerciseLogs)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<void> upsertExerciseLog(ExerciseLogsCompanion companion) {
    return into(exerciseLogs).insertOnConflictUpdate(companion);
  }

  Future<int> deleteExerciseLog(String id) {
    return (delete(exerciseLogs)..where((t) => t.id.equals(id))).go();
  }

  // Set logs

  Stream<List<SetLogRow>> watchSetsForExerciseLog(String exerciseLogId) {
    return (select(setLogs)
          ..where((t) => t.exerciseLogId.equals(exerciseLogId))
          ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
        .watch();
  }

  Future<void> upsertSetLog(SetLogsCompanion companion) {
    return into(setLogs).insertOnConflictUpdate(companion);
  }

  Future<int> deleteSetLog(String id) {
    return (delete(setLogs)..where((t) => t.id.equals(id))).go();
  }
}
