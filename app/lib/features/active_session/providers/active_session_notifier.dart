import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'active_session_providers.dart';

part 'active_session_notifier.g.dart';

// ---------------------------------------------------------------------------
// State models
// ---------------------------------------------------------------------------

/// Holds the logged sets and previous-performance reference for a single
/// exercise within an active session.
class ActiveExerciseData {
  const ActiveExerciseData({
    required this.planExercise,
    this.exerciseLogId,
    this.loggedSets = const [],
    this.previousSets = const [],
  });

  /// The exercise as planned (with targets). For ad-hoc exercises added
  /// mid-workout, targets are all null.
  final PlanDayExercise planExercise;

  /// Local Drift ID for the exercise_log row, set after the first set is logged.
  final String? exerciseLogId;

  /// Sets logged so far in this session for this exercise.
  final List<SetLog> loggedSets;

  /// Sets logged in the most recent prior completed session (for reference).
  final List<SetLog> previousSets;

  ActiveExerciseData copyWith({
    String? exerciseLogId,
    List<SetLog>? loggedSets,
    List<SetLog>? previousSets,
  }) =>
      ActiveExerciseData(
        planExercise: planExercise,
        exerciseLogId: exerciseLogId ?? this.exerciseLogId,
        loggedSets: loggedSets ?? this.loggedSets,
        previousSets: previousSets ?? this.previousSets,
      );
}

/// Immutable state for the active workout session.
class ActiveSessionState {
  const ActiveSessionState({
    required this.session,
    required this.exerciseData,
    this.currentExerciseIndex = 0,
    this.isLoading = false,
  });

  final WorkoutSession session;

  /// One entry per exercise (planned + any ad-hoc additions).
  final List<ActiveExerciseData> exerciseData;

  /// Index into [exerciseData] identifying the exercise currently being logged.
  final int currentExerciseIndex;

  /// True while an async operation (logSet, complete, abandon) is in flight.
  final bool isLoading;

  ActiveExerciseData get currentExercise => exerciseData[currentExerciseIndex];

  bool get hasExercises => exerciseData.isNotEmpty;

  bool get isLastExercise => currentExerciseIndex >= exerciseData.length - 1;

  bool get isFirstExercise => currentExerciseIndex == 0;

  ActiveSessionState copyWith({
    WorkoutSession? session,
    List<ActiveExerciseData>? exerciseData,
    int? currentExerciseIndex,
    bool? isLoading,
  }) =>
      ActiveSessionState(
        session: session ?? this.session,
        exerciseData: exerciseData ?? this.exerciseData,
        currentExerciseIndex:
            currentExerciseIndex ?? this.currentExerciseIndex,
        isLoading: isLoading ?? this.isLoading,
      );
}

/// Holds the workout summary shown after session completion.
class WorkoutSummary {
  const WorkoutSummary({
    required this.session,
    required this.exerciseData,
    required this.newPRs,
    required this.totalSets,
    required this.durationSec,
  });

  final WorkoutSession session;
  final List<ActiveExerciseData> exerciseData;
  final List<NewPersonalRecord> newPRs;
  final int totalSets;
  final int durationSec;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the lifecycle of an active workout session. Persists across
/// navigation since it is [keepAlive: true].
///
/// Usage:
/// ```dart
/// // Start a new session:
/// await ref.read(activeSessionNotifierProvider.notifier).startSession(
///   planId: plan.id,
///   planDayId: day.id,
///   exercises: day.exercises,
/// );
///
/// // Log a set:
/// await ref.read(activeSessionNotifierProvider.notifier).logSet(
///   reps: 10, weightKg: 80.0,
/// );
///
/// // Complete:
/// final summary = await ref.read(activeSessionNotifierProvider.notifier)
///     .completeSession();
/// ```
@Riverpod(keepAlive: true)
class ActiveSessionNotifier extends _$ActiveSessionNotifier {
  // Tracks the wall-clock start of the current session for duration calculation.
  DateTime? _sessionStartTime;

  // ── Fix #7: guard against concurrent startSession calls ───────────────────
  // Set synchronously before the first await so a second call arriving while
  // the first is in flight is rejected immediately.
  bool _isStartingSession = false;

  @override
  ActiveSessionState? build() => null;

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  /// Creates a new session on the server and loads previous-performance data
  /// for every exercise. Sets state to [ActiveSessionState] on success.
  Future<void> startSession({
    required String? planId,
    required String? planDayId,
    required List<PlanDayExercise> exercises,
  }) async {
    // Reject concurrent start calls (e.g. double-tap) and ignore if a session
    // is already active to prevent orphaned server sessions.
    if (_isStartingSession || state != null) return;
    _isStartingSession = true;

    final repo = ref.read(workoutSessionRepositoryProvider);

    try {
      final session = await repo.startSession(
        planId: planId,
        planDayId: planDayId,
      );

      _sessionStartTime = session.startedAt;

      // Load previous sets for each exercise in parallel.
      final previousSets = await Future.wait(
        exercises.map((ex) => repo
            .getPreviousSets(
              exerciseId: ex.exerciseId,
              excludeSessionId: session.id,
            )
            .catchError((_) => <SetLog>[])),
      );

      state = ActiveSessionState(
        session: session,
        exerciseData: List.generate(
          exercises.length,
          (i) => ActiveExerciseData(
            planExercise: exercises[i],
            previousSets: previousSets[i],
          ),
        ),
      );
    } finally {
      _isStartingSession = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Set logging
  // ---------------------------------------------------------------------------

  /// Logs the next set for the current exercise.
  Future<SetLog?> logSet({
    int? reps,
    double? weightKg,
    int? durationSec,
    double? distanceM,
    int? heartRate,
    int? rpe,
    String? tempo,
    bool isWarmup = false,
  }) async {
    final current = state;
    if (current == null || current.isLoading) return null;

    state = current.copyWith(isLoading: true);

    try {
      final currentEx = current.currentExercise;
      final nextSetNumber = currentEx.loggedSets.length + 1;
      final completedAt = DateTime.now();

      // Auto-calculate pace when both duration and distance are present.
      final paceSecPerKm =
          (durationSec != null && distanceM != null && distanceM > 0)
              ? durationSec / (distanceM / 1000)
              : null;

      final setLog = await ref.read(workoutSessionRepositoryProvider).logSet(
            sessionId: current.session.id,
            exerciseId: currentEx.planExercise.exerciseId,
            setNumber: nextSetNumber,
            reps: reps,
            weightKg: weightKg,
            durationSec: durationSec,
            distanceM: distanceM,
            paceSecPerKm: paceSecPerKm,
            heartRate: heartRate,
            rpe: rpe,
            tempo: tempo,
            isWarmup: isWarmup,
            completedAt: completedAt,
          );

      final updatedData = List<ActiveExerciseData>.from(current.exerciseData);
      updatedData[current.currentExerciseIndex] =
          currentEx.copyWith(
        exerciseLogId: setLog.exerciseLogId,
        loggedSets: [...currentEx.loggedSets, setLog],
      );

      state = current.copyWith(
        exerciseData: updatedData,
        isLoading: false,
      );

      return setLog;
    } catch (e) {
      state = current.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Removes a set from the current exercise's logged sets.
  ///
  /// ── Fix #5: update in-memory state only after the local DB delete confirms.
  /// If the Drift delete fails, the state is left untouched so it stays
  /// consistent with the DB — no ghost sets can re-appear on next rebuild.
  Future<void> deleteSet(SetLog setLog) async {
    final current = state;
    if (current == null) return;

    final currentEx = current.currentExercise;

    // Commit local delete first. Propagate any Drift error to the caller
    // so the UI can surface it; do NOT update state if this throws.
    await ref.read(workoutSessionRepositoryProvider).deleteSet(
          sessionId: current.session.id,
          setId: setLog.id,
          exerciseLogId: setLog.exerciseLogId,
        );

    // Local delete succeeded — update in-memory state.
    // Renumber remaining sets to keep set numbers sequential.
    final remaining =
        currentEx.loggedSets.where((s) => s.id != setLog.id).toList();
    final renumbered = List.generate(
      remaining.length,
      (i) => remaining[i].copyWith(setNumber: i + 1),
    );

    final updatedData = List<ActiveExerciseData>.from(current.exerciseData);
    updatedData[current.currentExerciseIndex] =
        currentEx.copyWith(loggedSets: renumbered);

    state = current.copyWith(exerciseData: updatedData);
  }

  // ---------------------------------------------------------------------------
  // Exercise navigation
  // ---------------------------------------------------------------------------

  void nextExercise() {
    final current = state;
    if (current == null || current.isLastExercise) return;
    state =
        current.copyWith(currentExerciseIndex: current.currentExerciseIndex + 1);
  }

  void previousExercise() {
    final current = state;
    if (current == null || current.isFirstExercise) return;
    state =
        current.copyWith(currentExerciseIndex: current.currentExerciseIndex - 1);
  }

  void goToExercise(int index) {
    final current = state;
    if (current == null) return;
    if (index < 0 || index >= current.exerciseData.length) return;
    state = current.copyWith(currentExerciseIndex: index);
  }

  /// Skips the current exercise (moves to next without logging any sets).
  void skipExercise() => nextExercise();

  /// Adds an exercise not in the original plan to the end of the exercise list.
  Future<void> addExercise(Exercise exercise) async {
    final current = state;
    if (current == null) return;

    // Create a synthetic PlanDayExercise with no targets.
    final planExercise = PlanDayExercise(
      id: 'adhoc-${exercise.id}',
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      exerciseType: exercise.exerciseType,
      sortOrder: current.exerciseData.length,
    );

    final previousSets = await ref
        .read(workoutSessionRepositoryProvider)
        .getPreviousSets(
          exerciseId: exercise.id,
          excludeSessionId: current.session.id,
        )
        .catchError((_) => <SetLog>[]);

    final updatedData = [
      ...current.exerciseData,
      ActiveExerciseData(
        planExercise: planExercise,
        previousSets: previousSets,
      ),
    ];

    state = current.copyWith(
      exerciseData: updatedData,
      // Navigate to the newly added exercise.
      currentExerciseIndex: updatedData.length - 1,
    );
  }

  /// Replaces the current exercise with a different one (preserves position).
  Future<void> replaceCurrentExercise(Exercise exercise) async {
    final current = state;
    if (current == null) return;

    final planExercise = PlanDayExercise(
      id: 'adhoc-${exercise.id}',
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      exerciseType: exercise.exerciseType,
      sortOrder: current.currentExerciseIndex,
    );

    final previousSets = await ref
        .read(workoutSessionRepositoryProvider)
        .getPreviousSets(
          exerciseId: exercise.id,
          excludeSessionId: current.session.id,
        )
        .catchError((_) => <SetLog>[]);

    final updatedData = List<ActiveExerciseData>.from(current.exerciseData);
    updatedData[current.currentExerciseIndex] = ActiveExerciseData(
      planExercise: planExercise,
      previousSets: previousSets,
    );

    state = current.copyWith(exerciseData: updatedData);
  }

  // ---------------------------------------------------------------------------
  // Session completion / abandonment
  // ---------------------------------------------------------------------------

  /// Completes the session and returns a [WorkoutSummary].
  Future<WorkoutSummary> completeSession({String? notes}) async {
    final current = state;
    if (current == null) throw StateError('No active session');

    state = current.copyWith(isLoading: true);

    try {
      final completedAt = DateTime.now();
      final durationSec = completedAt
          .difference(_sessionStartTime ?? current.session.startedAt)
          .inSeconds;

      final result =
          await ref.read(workoutSessionRepositoryProvider).completeSession(
                sessionId: current.session.id,
                completedAt: completedAt,
                durationSec: durationSec,
                notes: notes,
              );

      final totalSets = current.exerciseData
          .fold<int>(0, (sum, ex) => sum + ex.loggedSets.length);

      final summary = WorkoutSummary(
        session: result.session,
        exerciseData: current.exerciseData,
        newPRs: result.newPRs,
        totalSets: totalSets,
        durationSec: durationSec,
      );

      // Clear the active session state.
      state = null;
      _sessionStartTime = null;

      return summary;
    } catch (e) {
      state = current.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Abandons the session without saving a summary.
  Future<void> abandonSession() async {
    final current = state;
    if (current == null) return;

    try {
      await ref
          .read(workoutSessionRepositoryProvider)
          .abandonSession(current.session.id);
    } catch (e) {
      debugPrint('ActiveSessionNotifier: abandonSession failed: $e');
    }

    state = null;
    _sessionStartTime = null;
  }
}
