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

  // Future-based point lookups (no stream overhead, no race from .first)

  /// Returns a single session by [id], or null if not found.
  Future<WorkoutSessionRow?> getSession(String id) {
    return (select(workoutSessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Returns all exercise logs for [sessionId] as a one-shot Future.
  ///
  /// Use this instead of `watchLogsForSession(sessionId).first` to avoid
  /// opening and immediately tearing down a reactive DB subscription on every
  /// call.
  Future<List<ExerciseLogRow>> getLogsForSession(String sessionId) {
    return (select(exerciseLogs)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Returns the exercise log for a given (session, exercise) pair, or null.
  ///
  /// Used by `logSet` to find-or-create an exercise log without opening a
  /// reactive stream subscription.
  Future<ExerciseLogRow?> getExerciseLogForSessionAndExercise(
      String sessionId, String exerciseId) {
    return (select(exerciseLogs)
          ..where((t) =>
              t.sessionId.equals(sessionId) &
              t.exerciseId.equals(exerciseId)))
        .getSingleOrNull();
  }

  /// Returns the set logs from the most recent completed session in which
  /// [exerciseId] was performed by [userId].
  ///
  /// Pass [excludeSessionId] (the current in-progress session) to ensure the
  /// current session's own sets are never returned as "previous" performance.
  Future<List<SetLogRow>> getPreviousSetsForExercise({
    required String userId,
    required String exerciseId,
    String? excludeSessionId,
  }) async {
    // Step 1 — find the most recent completed session that logged this exercise.
    final sessionQuery = select(workoutSessions).join([
      innerJoin(
        exerciseLogs,
        exerciseLogs.sessionId.equalsExp(workoutSessions.id),
      ),
    ])
      ..addColumns([workoutSessions.id])
      ..where(workoutSessions.userId.equals(userId))
      ..where(exerciseLogs.exerciseId.equals(exerciseId))
      ..where(workoutSessions.status.equals(
        const SessionStatusConverter().toSql(SessionStatus.completed),
      ))
      ..orderBy([OrderingTerm.desc(workoutSessions.startedAt)])
      ..limit(1);

    if (excludeSessionId != null) {
      sessionQuery.where(workoutSessions.id.equals(excludeSessionId).not());
    }

    final sessionRows = await sessionQuery.get();
    if (sessionRows.isEmpty) return [];

    final sessionId = sessionRows.first.readTable(workoutSessions).id;

    // Step 2 — find the exercise log for that session + exercise.
    final logRow = await (select(exerciseLogs)
          ..where((t) =>
              t.sessionId.equals(sessionId) &
              t.exerciseId.equals(exerciseId)))
        .getSingleOrNull();
    if (logRow == null) return [];

    // Step 3 — return all sets for that exercise log, ordered by set number.
    return (select(setLogs)
          ..where((t) => t.exerciseLogId.equals(logRow.id))
          ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
        .get();
  }
}
