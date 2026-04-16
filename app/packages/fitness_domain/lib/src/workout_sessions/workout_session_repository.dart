import 'workout_session.dart';

abstract class WorkoutSessionRepository {
  /// Creates a new workout session. Writes to local DB and syncs to the server.
  Future<WorkoutSession> startSession({
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
    int? rpe,
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

  /// Returns the set logs from the most recent completed session in which
  /// [exerciseId] was performed. Used to display previous performance.
  Future<List<SetLog>> getPreviousSets({
    required String exerciseId,
    String? excludeSessionId,
  });
}

class SessionCompletionResult {
  const SessionCompletionResult({
    required this.session,
    required this.newPRs,
  });

  final WorkoutSession session;
  final List<NewPersonalRecord> newPRs;
}
