import 'package:drift/drift.dart';

import '../app_database.dart';
import '../converters/session_status_converter.dart';
import '../tables/exercise_library_tables.dart';
import '../tables/workout_plan_tables.dart';
import '../tables/workout_session_tables.dart';

part 'workout_session_dao.g.dart';

@DriftAccessor(
    tables: [WorkoutSessions, ExerciseLogs, SetLogs, Exercises, WorkoutPlans])
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

  // History queries

  /// Streams all completed sessions for [userId], ordered newest first.
  Stream<List<WorkoutSessionRow>> watchCompletedSessions(String userId) {
    return (select(workoutSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.status.equals(
                const SessionStatusConverter().toSql(SessionStatus.completed),
              ))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  /// Returns exercise counts keyed by session ID for all [sessionIds].
  /// One query for all sessions — avoids N+1 pattern.
  Future<Map<String, int>> getBatchExerciseCounts(
      List<String> sessionIds) async {
    if (sessionIds.isEmpty) return {};
    final rows = await (select(exerciseLogs)
          ..where((t) => t.sessionId.isIn(sessionIds)))
        .get();
    final counts = <String, int>{};
    for (final row in rows) {
      counts[row.sessionId] = (counts[row.sessionId] ?? 0) + 1;
    }
    return counts;
  }

  /// Returns total set counts (all sets, including warmup) keyed by session ID
  /// for all [sessionIds]. One query for all sessions — avoids N+1 pattern.
  Future<Map<String, int>> getBatchTotalSets(List<String> sessionIds) async {
    if (sessionIds.isEmpty) return {};
    final query = select(setLogs).join([
      innerJoin(
          exerciseLogs, exerciseLogs.id.equalsExp(setLogs.exerciseLogId)),
    ])
      ..where(exerciseLogs.sessionId.isIn(sessionIds));
    final rows = await query.get();
    final counts = <String, int>{};
    for (final row in rows) {
      final sessionId = row.readTable(exerciseLogs).sessionId;
      counts[sessionId] = (counts[sessionId] ?? 0) + 1;
    }
    return counts;
  }

  /// Returns total volume (sum of reps × weightKg, non-warmup strength sets)
  /// keyed by session ID for all [sessionIds]. One query — avoids N+1 pattern.
  Future<Map<String, double>> getBatchTotalVolumes(
      List<String> sessionIds) async {
    if (sessionIds.isEmpty) return {};
    final query = select(setLogs).join([
      innerJoin(
          exerciseLogs, exerciseLogs.id.equalsExp(setLogs.exerciseLogId)),
    ])
      ..where(exerciseLogs.sessionId.isIn(sessionIds))
      ..where(setLogs.isWarmup.equals(false))
      ..where(setLogs.reps.isNotNull())
      ..where(setLogs.weightKg.isNotNull());
    final rows = await query.get();
    final volumes = <String, double>{};
    for (final row in rows) {
      final setRow = row.readTable(setLogs);
      final sessionId = row.readTable(exerciseLogs).sessionId;
      volumes[sessionId] =
          (volumes[sessionId] ?? 0.0) + (setRow.reps! * setRow.weightKg!);
    }
    return volumes;
  }

  /// Returns plan name strings keyed by plan ID for all [planIds].
  /// One query for all plans — avoids N+1 pattern.
  Future<Map<String, String>> getBatchPlanNames(List<String> planIds) async {
    if (planIds.isEmpty) return {};
    final rows = await (select(workoutPlans)
          ..where((t) => t.id.isIn(planIds)))
        .get();
    return {for (final row in rows) row.id: row.name};
  }

  /// Returns the total lifted volume (sum of reps × weightKg) for all
  /// non-warmup strength sets in [sessionId].
  Future<double> getTotalVolumeForSession(String sessionId) async {
    final query = customSelect(
      '''
      SELECT COALESCE(SUM(sl.reps * sl.weight_kg), 0.0) AS total_volume
      FROM set_logs sl
      INNER JOIN exercise_logs el ON sl.exercise_log_id = el.id
      WHERE el.session_id = ? AND sl.is_warmup = 0
        AND sl.reps IS NOT NULL AND sl.weight_kg IS NOT NULL
      ''',
      variables: [Variable.withString(sessionId)],
      readsFrom: {setLogs, exerciseLogs},
    );
    final result = await query.getSingleOrNull();
    if (result == null) return 0.0;
    return (result.data['total_volume'] as num).toDouble();
  }

  /// Returns the total number of sets logged for [sessionId].
  Future<int> getTotalSetsForSession(String sessionId) async {
    final query = customSelect(
      '''
      SELECT COUNT(*) AS total_sets
      FROM set_logs sl
      INNER JOIN exercise_logs el ON sl.exercise_log_id = el.id
      WHERE el.session_id = ?
      ''',
      variables: [Variable.withString(sessionId)],
      readsFrom: {setLogs, exerciseLogs},
    );
    final result = await query.getSingleOrNull();
    if (result == null) return 0;
    // Use (as num).toInt() — SQLite may return numeric results as double
    // on iOS even for COUNT(*), which would throw with a direct `as int` cast.
    return (result.data['total_sets'] as num).toInt();
  }

  /// Returns exercise logs for [sessionId] with exercise names resolved by
  /// joining with the exercises table. Ordered by sort_order.
  Future<List<({ExerciseLogRow log, String exerciseName, String exerciseType})>>
      getLogsWithNamesForSession(String sessionId) async {
    final query = select(exerciseLogs).join([
      innerJoin(exercises, exercises.id.equalsExp(exerciseLogs.exerciseId)),
    ])
      ..where(exerciseLogs.sessionId.equals(sessionId))
      ..orderBy([OrderingTerm.asc(exerciseLogs.sortOrder)]);

    final rows = await query.get();
    return rows.map((row) {
      final log = row.readTable(exerciseLogs);
      final exercise = row.readTable(exercises);
      return (
        log: log,
        exerciseName: exercise.name,
        exerciseType: exercise.exerciseType.name,
      );
    }).toList();
  }

  /// Returns all set logs for [exerciseLogId] ordered by set number.
  Future<List<SetLogRow>> getSetsForExerciseLog(String exerciseLogId) {
    return (select(setLogs)
          ..where((t) => t.exerciseLogId.equals(exerciseLogId))
          ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]))
        .get();
  }

  /// Returns the most recent completed session in which
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
