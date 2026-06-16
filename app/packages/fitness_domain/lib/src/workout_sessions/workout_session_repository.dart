import 'previous_session_data.dart';
import 'workout_session.dart';
import 'workout_session_summary.dart';

abstract class WorkoutSessionRepository {
  /// Creates a new workout session. Writes to local DB and syncs to the server.
  /// Returns the session and server-computed suggested weights keyed by exerciseId.
  Future<SessionStartResult> startSession({
    String? planId,
    String? planDayId,
    DateTime? startedAt,
  });

  /// Returns a stream of the current user's in-progress session, or null when
  /// no session is active. Uses local DB for offline-first reactivity.
  Stream<WorkoutSession?> watchActiveSession();

  /// Logs a single set for an exercise within [sessionId]. Creates an exercise
  /// log entry automatically on the first set for each exercise.
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
    double? rpe,
    String? tempo,
    bool isWarmup,
    DateTime? completedAt,
  });

  /// Permanently removes a set log from [sessionId].
  Future<void> deleteSet({
    required String sessionId,
    required String setId,
    required String exerciseLogId,
  });

  /// Marks the session as complete and triggers streak + personal record
  /// evaluation on the server.
  Future<SessionCompletionResult> completeSession({
    required String sessionId,
    required DateTime completedAt,
    required int durationSec,
    String? notes,
  });

  /// Marks the session as abandoned and persists that state locally.
  Future<void> abandonSession(String sessionId);

  /// Returns set logs from the last [limit] completed sessions in which
  /// [exerciseId] was performed. Used to display previous performance.
  Future<List<PreviousSessionData>> getPreviousSessions({
    required String exerciseId,
    String? excludeSessionId,
    int limit = 3,
  });

  /// Streams summary data for all completed sessions, newest first.
  /// Uses local DB for offline-first reactivity. The caller is responsible
  /// for triggering server sync via [syncCompletedSessions].
  Stream<List<WorkoutSessionSummary>> watchCompletedSessions();

  /// Fetches completed sessions from the server and upserts any missing rows
  /// into the local DB, using cursor-based pagination to cover all pages.
  Future<void> syncCompletedSessions();

  /// Returns the exercise logs (with nested sets) for a single completed
  /// session. Reads from local DB first; falls back to the server if no
  /// local exercise data exists (e.g. session completed on another device).
  Future<List<ExerciseLog>> getSessionExerciseLogs(String sessionId);
}

class SessionStartResult {
  const SessionStartResult({
    required this.session,
    this.suggestedWeights = const {},
  });

  final WorkoutSession session;
  // exerciseId → suggested weight in kg (based on PR × targetWeightPct1rm)
  final Map<String, double> suggestedWeights;
}

class SessionCompletionResult {
  const SessionCompletionResult({
    required this.session,
    required this.newPRs,
  });

  final WorkoutSession session;
  final List<NewPersonalRecord> newPRs;
}
