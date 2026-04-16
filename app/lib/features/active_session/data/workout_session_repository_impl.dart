import 'package:drift/drift.dart' show Value;
import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class WorkoutSessionRepositoryImpl implements WorkoutSessionRepository {
  WorkoutSessionRepositoryImpl({
    required SessionApiClient apiClient,
    required WorkoutSessionDao sessionDao,
    required String userId,
  })  : _apiClient = apiClient,
        _dao = sessionDao,
        _userId = userId;

  final SessionApiClient _apiClient;
  final WorkoutSessionDao _dao;
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
      // Fall through: the local stub is the canonical session until sync.
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
          rpe: Value(rpe),
          tempo: Value(tempo),
          isWarmup: Value(isWarmup),
          completedAt: Value(completedTime),
        ));
        canonicalSetId = serverSetId;
      }
    } catch (e) {
      debugPrint('WorkoutSessionRepository: logSet server sync failed: $e');
    }

    return SetLog(
      id: canonicalSetId,
      exerciseLogId: exerciseLogId,
      setNumber: setNumber,
      reps: reps,
      weightKg: weightKg,
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
    }
  }

  @override
  Future<SessionCompletionResult> completeSession({
    required String sessionId,
    required DateTime completedAt,
    required int durationSec,
    String? notes,
  }) async {
    // ── Fix #1 (offline-first): always persist locally ────────────────────────
    // Attempt the server call first (it calculates PRs and streak). If it
    // fails, still mark the session completed in Drift so the user's workout
    // is never lost. PRs will be recalculated on the next full sync.

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
    }

    // Fallback: persist completion locally so the user's workout is preserved.
    final now = DateTime.now();
    await _dao.upsertSession(WorkoutSessionsCompanion(
      id: Value(sessionId),
      status: const Value(SessionStatus.completed),
      completedAt: Value(completedAt),
      durationSec: Value(durationSec),
      notes: Value(notes),
      updatedAt: Value(now),
    ));

    // Reconstruct a minimal WorkoutSession from Drift (has startedAt etc.).
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

    // PRs cannot be calculated offline — they will sync on next connection.
    return SessionCompletionResult(session: session, newPRs: []);
  }

  @override
  Future<void> abandonSession(String sessionId) async {
    try {
      await _apiClient.updateSession(
        sessionId,
        const UpdateSessionRequestDto(status: 'abandoned'),
      );
    } catch (e) {
      debugPrint(
          'WorkoutSessionRepository: abandonSession server sync failed: $e');
    }

    await _dao.upsertSession(WorkoutSessionsCompanion(
      id: Value(sessionId),
      status: const Value(SessionStatus.abandoned),
      updatedAt: Value(DateTime.now()),
    ));
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
