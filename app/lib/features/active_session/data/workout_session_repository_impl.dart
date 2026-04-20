import 'package:drift/drift.dart' show Value;
import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/sync/sync_service.dart';

const _uuid = Uuid();

class WorkoutSessionRepositoryImpl implements WorkoutSessionRepository {
  WorkoutSessionRepositoryImpl({
    required SessionApiClient apiClient,
    required WorkoutSessionDao sessionDao,
    required SyncQueueDao syncQueueDao,
    required String userId,
  })  : _apiClient = apiClient,
        _dao = sessionDao,
        _syncDao = syncQueueDao,
        _userId = userId;

  final SessionApiClient _apiClient;
  final WorkoutSessionDao _dao;
  final SyncQueueDao _syncDao;
  final String _userId;

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  @override
  Stream<WorkoutSession?> watchActiveSession() {
    return _dao
        .watchActiveSession(_userId)
        .map((row) => row == null ? null : _rowToSession(row));
  }

  @override
  Stream<List<WorkoutSessionSummary>> watchCompletedSessions() {
    // Pure local DB stream. Sync is the caller's responsibility — triggered
    // by the CompletedSessions StreamNotifier's _syncInBackground().
    return _dao.watchCompletedSessions(_userId).asyncMap((rows) async {
      if (rows.isEmpty) return [];

      final ids = rows.map((r) => r.id).toList();
      final planIds =
          rows.map((r) => r.planId).whereType<String>().toSet().toList();

      // 4 batch queries → constant overhead, not O(N).
      // asyncMap on a single-subscriber Drift stream is sequential, so these
      // never run concurrently with a subsequent emission.
      final (exerciseCounts, totalSets, totalVolumes, planNames) = await (
        _dao.getBatchExerciseCounts(ids),
        _dao.getBatchTotalSets(ids),
        _dao.getBatchTotalVolumes(ids),
        _dao.getBatchPlanNames(planIds),
      ).wait;

      return rows.map((row) {
        // Issue #9 fix: null-safe completedAt — a completed-status row with
        // null completedAt (e.g. from a malformed server response) falls back
        // to startedAt rather than throwing a Null check error.
        final completedAt = row.completedAt ?? row.startedAt;
        return WorkoutSessionSummary(
          id: row.id,
          // Issue #8 fix: convert to local time so calendar grouping matches
          // what the user sees in the date display.
          startedAt: row.startedAt.toLocal(),
          completedAt: completedAt.toLocal(),
          durationSec: row.durationSec ?? 0,
          planId: row.planId,
          // Issue #7 fix: plan name resolved here so cards don't need to watch
          // the full plan list.
          planName: row.planId != null ? planNames[row.planId] : null,
          exerciseCount: exerciseCounts[row.id] ?? 0,
          // Issue #4 fix: totalSets counts all sets (including warmup) so
          // warmup-only sessions don't show "0 sets".
          totalSets: totalSets[row.id] ?? 0,
          totalVolumeKg: totalVolumes[row.id] ?? 0.0,
        );
      }).toList();
    });
  }

  @override
  Future<void> syncCompletedSessions() async {
    // Issue #10 fix: cursor-based pagination so all pages are fetched, not
    // just the first 50.
    try {
      String? cursor;
      do {
        final envelope = await _apiClient.listSessions(
          status: 'completed',
          limit: 50,
          cursor: cursor,
        );
        for (final dto in envelope.data.sessions) {
          await _dao.upsertSession(WorkoutSessionsCompanion(
            id: Value(dto.id),
            userId: Value(_userId),
            planId: Value(dto.planId),
            planDayId: Value(dto.planDayId),
            startedAt: Value(DateTime.parse(dto.startedAt)),
            completedAt: Value(dto.completedAt != null
                ? DateTime.parse(dto.completedAt!)
                : null),
            durationSec: Value(dto.durationSec),
            notes: Value(dto.notes),
            status:
                Value(const SessionStatusConverter().fromSql(dto.status)),
            createdAt: Value(DateTime.parse(dto.createdAt)),
            updatedAt: Value(DateTime.parse(dto.updatedAt)),
          ));
        }
        cursor = envelope.data.pagination.hasMore
            ? envelope.data.pagination.nextCursor
            : null;
      } while (cursor != null);
    } catch (e) {
      debugPrint(
          'WorkoutSessionRepository: syncCompletedSessions failed: $e');
    }
  }

  @override
  Future<List<ExerciseLog>> getSessionExerciseLogs(String sessionId) async {
    final logsWithNames = await _dao.getLogsWithNamesForSession(sessionId);

    if (logsWithNames.isNotEmpty) {
      return Future.wait(logsWithNames.map((entry) async {
        final sets = await _dao.getSetsForExerciseLog(entry.log.id);
        return ExerciseLog(
          id: entry.log.id,
          sessionId: sessionId,
          exerciseId: entry.log.exerciseId,
          exerciseName: entry.exerciseName,
          sortOrder: entry.log.sortOrder,
          notes: entry.log.notes,
          sets: sets.map(_rowToSetLog).toList(),
        );
      }));
    }

    // Issue #5 fix: local DB has no exercise logs (session completed on
    // another device). Fall back to the server's session detail endpoint.
    debugPrint(
        'WorkoutSessionRepository: no local exercise logs for $sessionId — fetching from server');
    try {
      final envelope = await _apiClient.getSession(sessionId);
      final dto = envelope.data.session;

      // Upsert exercise logs and set logs so subsequent opens are served
      // from local DB without another network call.
      for (final exerciseDto in dto.exercises) {
        await _dao.upsertExerciseLog(ExerciseLogsCompanion(
          id: Value(exerciseDto.id),
          sessionId: Value(sessionId),
          exerciseId: Value(exerciseDto.exerciseId),
          sortOrder: Value(exerciseDto.sortOrder),
          notes: Value(exerciseDto.notes),
        ));
        for (final setDto in exerciseDto.sets) {
          await _dao.upsertSetLog(SetLogsCompanion(
            id: Value(setDto.id),
            exerciseLogId: Value(exerciseDto.id),
            setNumber: Value(setDto.setNumber),
            reps: Value(setDto.reps),
            weightKg: Value(setDto.weightKg),
            durationSec: Value(setDto.durationSec),
            distanceM: Value(setDto.distanceM),
            paceSecPerKm: Value(setDto.paceSecPerKm),
            heartRate: Value(setDto.heartRate),
            rpe: Value(setDto.rpe),
            tempo: Value(setDto.tempo),
            isWarmup: Value(setDto.isWarmup),
            completedAt: Value(setDto.completedAt != null
                ? DateTime.parse(setDto.completedAt!)
                : null),
          ));
        }
      }

      // Return domain models directly from the DTO (exercise names are
      // available in the DTO even if exercises aren't yet in local DB).
      return dto.exercises.map((exerciseDto) => ExerciseLog(
            id: exerciseDto.id,
            sessionId: sessionId,
            exerciseId: exerciseDto.exerciseId,
            exerciseName: exerciseDto.exerciseName,
            sortOrder: exerciseDto.sortOrder,
            notes: exerciseDto.notes,
            sets: exerciseDto.sets
                .map((setDto) => SetLog(
                      id: setDto.id,
                      exerciseLogId: exerciseDto.id,
                      setNumber: setDto.setNumber,
                      reps: setDto.reps,
                      weightKg: setDto.weightKg,
                      durationSec: setDto.durationSec,
                      distanceM: setDto.distanceM,
                      paceSecPerKm: setDto.paceSecPerKm,
                      heartRate: setDto.heartRate,
                      rpe: setDto.rpe,
                      tempo: setDto.tempo,
                      isWarmup: setDto.isWarmup,
                      completedAt: setDto.completedAt != null
                          ? DateTime.parse(setDto.completedAt!)
                          : null,
                    ))
                .toList(),
          )).toList();
    } catch (e) {
      debugPrint(
          'WorkoutSessionRepository: getSessionExerciseLogs server fallback failed: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Write — session lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<WorkoutSession> startSession({
    String? planId,
    String? planDayId,
    DateTime? startedAt,
  }) async {
    // Guard: reject calls while the user has no authenticated identity.
    if (_userId.isEmpty) {
      throw StateError('Cannot start a session: user is not authenticated.');
    }

    final startTime = startedAt ?? DateTime.now();
    final localId = _uuid.v4();
    final now = DateTime.now();

    // ── Fix #1 (offline-first): write locally first ──────────────────────────
    // Commit a stub row immediately so the workout can proceed offline.
    await _dao.upsertSession(WorkoutSessionsCompanion(
      id: Value(localId),
      userId: Value(_userId),
      planId: Value(planId),
      planDayId: Value(planDayId),
      startedAt: Value(startTime),
      status: const Value(SessionStatus.inProgress),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    // ── Sync to server (best-effort) ─────────────────────────────────────────
    try {
      final dto = (await _apiClient.startSession(StartSessionRequestDto(
        planId: planId,
        planDayId: planDayId,
        startedAt: startTime.toIso8601String(),
      )))
          .data
          .session;

      // Replace the local stub with the server-assigned row.
      // This is safe — no child exercise_log rows exist yet at session start,
      // so there are no FK constraints to violate.
      await _dao.transaction(() async {
        await _dao.deleteSession(localId);
        await _dao.upsertSession(_sessionDtoToCompanion(dto));
      });

      return _dtoToSession(dto);
    } catch (e) {
      debugPrint('WorkoutSessionRepository: startSession server sync failed: $e');
      // Enqueue so the sync engine retries when connectivity returns.
      await enqueueSyncItem(
        dao: _syncDao,
        userId: _userId,
        entityTable: 'workout_sessions',
        recordId: localId,
        operation: SyncOperation.create,
        payload: {
          'planId': planId,
          'planDayId': planDayId,
          'startedAt': startTime.toIso8601String(),
          'status': 'in_progress',
        },
      );
    }

    return WorkoutSession(
      id: localId,
      userId: _userId,
      planId: planId,
      planDayId: planDayId,
      startedAt: startTime,
      status: SessionStatus.inProgress,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<SetLog> logSet({
    required String sessionId,
    required String exerciseId,
    required int setNumber,
    int? reps,
    double? weightKg,
    int? durationSec,
    double? distanceM,
    double? paceSecPerKm,
    int? heartRate,
    int? rpe,
    String? tempo,
    bool isWarmup = false,
    DateTime? completedAt,
  }) async {
    final completedTime = completedAt ?? DateTime.now();

    // ── Fix #3: use Future-based DAO lookups, not .watch().first ─────────────
    // watchLogsForSession(sessionId).first opens + tears down a reactive DB
    // subscription on every call, creating a race if two logSet calls arrive
    // concurrently (both see no exercise log → both create one).

    // Find or create the exercise log for this (session, exercise) pair.
    final existingLog = await _dao.getExerciseLogForSessionAndExercise(
        sessionId, exerciseId);

    final localExerciseLogId = _uuid.v4();
    final localSetLogId = _uuid.v4();

    final exerciseLogId = existingLog?.id ?? localExerciseLogId;

    if (existingLog == null) {
      // Determine sort order from current log count (one Future, not a stream).
      final existingLogs = await _dao.getLogsForSession(sessionId);
      await _dao.upsertExerciseLog(ExerciseLogsCompanion(
        id: Value(exerciseLogId),
        sessionId: Value(sessionId),
        exerciseId: Value(exerciseId),
        sortOrder: Value(existingLogs.length),
      ));
    }

    await _dao.upsertSetLog(SetLogsCompanion(
      id: Value(localSetLogId),
      exerciseLogId: Value(exerciseLogId),
      setNumber: Value(setNumber),
      reps: Value(reps),
      weightKg: Value(weightKg),
      durationSec: Value(durationSec),
      distanceM: Value(distanceM),
      paceSecPerKm: Value(paceSecPerKm),
      heartRate: Value(heartRate),
      rpe: Value(rpe),
      tempo: Value(tempo),
      isWarmup: Value(isWarmup),
      completedAt: Value(completedTime),
    ));

    // ── Sync to server (best-effort) ─────────────────────────────────────────
    var canonicalSetId = localSetLogId;
    try {
      final response = await _apiClient.logSet(
        sessionId,
        LogSetRequestDto(
          exerciseId: exerciseId,
          setNumber: setNumber,
          reps: reps,
          weightKg: weightKg,
          durationSec: durationSec,
          distanceM: distanceM,
          paceSecPerKm: paceSecPerKm,
          heartRate: heartRate,
          rpe: rpe,
          tempo: tempo,
          isWarmup: isWarmup,
          completedAt: completedTime.toIso8601String(),
        ),
      );

      // ── Fix #2: reconcile local UUID with server UUID ─────────────────────
      // The server assigns its own UUID. Replace the local set log row so that
      // future deleteSet calls use the correct server-side ID.
      final serverSetId = response.data.set.id;
      if (serverSetId != localSetLogId) {
        await _dao.deleteSetLog(localSetLogId);
        await _dao.upsertSetLog(SetLogsCompanion(
          id: Value(serverSetId),
          exerciseLogId: Value(exerciseLogId),
          setNumber: Value(setNumber),
          reps: Value(reps),
          weightKg: Value(weightKg),
          durationSec: Value(durationSec),
          distanceM: Value(distanceM),
          paceSecPerKm: Value(paceSecPerKm),
          heartRate: Value(heartRate),
          rpe: Value(rpe),
          tempo: Value(tempo),
          isWarmup: Value(isWarmup),
          completedAt: Value(completedTime),
        ));
        canonicalSetId = serverSetId;
      }
    } catch (e) {
      debugPrint('WorkoutSessionRepository: logSet server sync failed: $e');
      await enqueueSyncItem(
        dao: _syncDao,
        userId: _userId,
        entityTable: 'set_logs',
        recordId: localSetLogId,
        operation: SyncOperation.create,
        payload: {
          'exerciseLogId': exerciseLogId,
          'sessionId': sessionId,
          'exerciseId': exerciseId,
          'setNumber': setNumber,
          if (reps != null) 'reps': reps,
          if (weightKg != null) 'weightKg': weightKg,
          if (durationSec != null) 'durationSec': durationSec,
          if (distanceM != null) 'distanceM': distanceM,
          if (paceSecPerKm != null) 'paceSecPerKm': paceSecPerKm,
          if (heartRate != null) 'heartRate': heartRate,
          if (rpe != null) 'rpe': rpe,
          if (tempo != null) 'tempo': tempo,
          'isWarmup': isWarmup,
          'completedAt': completedTime.toIso8601String(),
        },
      );
    }

    return SetLog(
      id: canonicalSetId,
      exerciseLogId: exerciseLogId,
      setNumber: setNumber,
      reps: reps,
      weightKg: weightKg,
      durationSec: durationSec,
      distanceM: distanceM,
      paceSecPerKm: paceSecPerKm,
      heartRate: heartRate,
      rpe: rpe,
      tempo: tempo,
      isWarmup: isWarmup,
      completedAt: completedTime,
    );
  }

  @override
  Future<void> deleteSet({
    required String sessionId,
    required String setId,
    required String exerciseLogId,
  }) async {
    // ── Fix #5 (partial): delete from Drift first, then sync ─────────────────
    await _dao.deleteSetLog(setId);

    try {
      // setId is now always the server-reconciled UUID (see logSet fix #2),
      // so this call correctly targets the server row.
      await _apiClient.deleteSet(sessionId, setId);
    } catch (e) {
      debugPrint('WorkoutSessionRepository: deleteSet server sync failed: $e');
      await enqueueSyncItem(
        dao: _syncDao,
        userId: _userId,
        entityTable: 'set_logs',
        recordId: setId,
        operation: SyncOperation.delete,
        payload: {'sessionId': sessionId, 'exerciseLogId': exerciseLogId},
      );
    }
  }

  @override
  Future<SessionCompletionResult> completeSession({
    required String sessionId,
    required DateTime completedAt,
    required int durationSec,
    String? notes,
  }) async {
    // ── Issue 19 fix: write locally FIRST (true offline-first) ───────────────
    // Persisting to Drift before the server call means the user's workout is
    // always recorded even if the server call succeeds but the subsequent Drift
    // write fails. The server response (PRs, streak) then upgrades the record
    // if connectivity is available.
    final now = DateTime.now();
    await _dao.upsertSession(WorkoutSessionsCompanion(
      id: Value(sessionId),
      status: const Value(SessionStatus.completed),
      completedAt: Value(completedAt),
      durationSec: Value(durationSec),
      notes: Value(notes),
      updatedAt: Value(now),
    ));

    // ── Sync to server (best-effort — server computes PRs and streak) ─────────
    try {
      final envelope = await _apiClient.completeSession(
        sessionId,
        CompleteSessionRequestDto(
          completedAt: completedAt.toIso8601String(),
          durationSec: durationSec,
          notes: notes,
        ),
      );
      final sessionDto = envelope.data.session;
      // Overwrite the local stub with the full server response.
      await _dao.upsertSession(_sessionDtoToCompanion(sessionDto));

      return SessionCompletionResult(
        session: _dtoToSession(sessionDto),
        newPRs: envelope.data.newPersonalRecords
            .map((pr) => NewPersonalRecord(
                  exerciseId: pr.exerciseId,
                  exerciseName: pr.exerciseName,
                  recordType: pr.recordType,
                  value: pr.value,
                  achievedAt: DateTime.parse(pr.achievedAt),
                ))
            .toList(),
      );
    } catch (e) {
      debugPrint(
          'WorkoutSessionRepository: completeSession server sync failed: $e');
      // Enqueue so the server can recalculate PRs and streak on next sync.
      await enqueueSyncItem(
        dao: _syncDao,
        userId: _userId,
        entityTable: 'workout_sessions',
        recordId: sessionId,
        operation: SyncOperation.update,
        payload: {
          'status': 'completed',
          'completedAt': completedAt.toIso8601String(),
          'durationSec': durationSec,
          if (notes != null) 'notes': notes,
        },
      );
    }

    // Reconstruct from Drift (already written above). PRs will sync later.
    final row = await _dao.getSession(sessionId);
    final session = row != null
        ? _rowToSession(row)
        : WorkoutSession(
            id: sessionId,
            userId: _userId,
            startedAt: completedAt.subtract(Duration(seconds: durationSec)),
            completedAt: completedAt,
            durationSec: durationSec,
            notes: notes,
            status: SessionStatus.completed,
            createdAt: now,
            updatedAt: now,
          );

    return SessionCompletionResult(session: session, newPRs: []);
  }

  @override
  Future<void> abandonSession(String sessionId) async {
    // Fix #9: write locally first (offline-first pattern) so the session is
    // always marked abandoned in Drift regardless of network state. Without
    // this, a Drift error after a successful server call leaves the two stores
    // permanently out of sync — watchActiveSession() would keep surfacing the
    // "Resume workout?" prompt for a session the server has already closed.
    await _dao.upsertSession(WorkoutSessionsCompanion(
      id: Value(sessionId),
      status: const Value(SessionStatus.abandoned),
      updatedAt: Value(DateTime.now()),
    ));

    try {
      await _apiClient.updateSession(
        sessionId,
        const UpdateSessionRequestDto(status: 'abandoned'),
      );
    } catch (e) {
      debugPrint(
          'WorkoutSessionRepository: abandonSession server sync failed: $e');
      await enqueueSyncItem(
        dao: _syncDao,
        userId: _userId,
        entityTable: 'workout_sessions',
        recordId: sessionId,
        operation: SyncOperation.update,
        payload: {'status': 'abandoned'},
      );
    }
  }

  @override
  Future<List<SetLog>> getPreviousSets({
    required String exerciseId,
    String? excludeSessionId,
  }) async {
    final rows = await _dao.getPreviousSetsForExercise(
      userId: _userId,
      exerciseId: exerciseId,
      excludeSessionId: excludeSessionId,
    );
    return rows.map(_rowToSetLog).toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  WorkoutSession _rowToSession(WorkoutSessionRow row) {
    return WorkoutSession(
      id: row.id,
      userId: row.userId,
      planId: row.planId,
      planDayId: row.planDayId,
      startedAt: row.startedAt,
      completedAt: row.completedAt,
      durationSec: row.durationSec,
      notes: row.notes,
      status: row.status,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  WorkoutSession _dtoToSession(SessionDetailDto dto) {
    return WorkoutSession(
      id: dto.id,
      userId: _userId,
      planId: dto.planId,
      planDayId: dto.planDayId,
      startedAt: DateTime.parse(dto.startedAt),
      completedAt:
          dto.completedAt != null ? DateTime.parse(dto.completedAt!) : null,
      durationSec: dto.durationSec,
      notes: dto.notes,
      status: const SessionStatusConverter().fromSql(dto.status),
      createdAt: DateTime.parse(dto.createdAt),
      updatedAt: DateTime.parse(dto.updatedAt),
    );
  }

  SetLog _rowToSetLog(SetLogRow row) {
    return SetLog(
      id: row.id,
      exerciseLogId: row.exerciseLogId,
      setNumber: row.setNumber,
      reps: row.reps,
      weightKg: row.weightKg,
      durationSec: row.durationSec,
      distanceM: row.distanceM,
      paceSecPerKm: row.paceSecPerKm,
      heartRate: row.heartRate,
      rpe: row.rpe,
      tempo: row.tempo,
      isWarmup: row.isWarmup,
      completedAt: row.completedAt,
    );
  }

  WorkoutSessionsCompanion _sessionDtoToCompanion(SessionDetailDto dto) {
    return WorkoutSessionsCompanion(
      id: Value(dto.id),
      userId: Value(_userId),
      planId: Value(dto.planId),
      planDayId: Value(dto.planDayId),
      startedAt: Value(DateTime.parse(dto.startedAt)),
      completedAt: Value(
          dto.completedAt != null ? DateTime.parse(dto.completedAt!) : null),
      durationSec: Value(dto.durationSec),
      notes: Value(dto.notes),
      status: Value(const SessionStatusConverter().fromSql(dto.status)),
      createdAt: Value(DateTime.parse(dto.createdAt)),
      updatedAt: Value(DateTime.parse(dto.updatedAt)),
    );
  }
}
