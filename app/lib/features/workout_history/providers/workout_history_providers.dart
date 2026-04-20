import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../active_session/providers/active_session_providers.dart';

part 'workout_history_providers.g.dart';

/// Streams all completed sessions for the current user, newest first.
///
/// keepAlive: true so the calendar and list views share the same Drift
/// subscription without re-fetching when the user toggles between them.
///
/// Mirrors the PlanList pattern: a [_hasSynced] guard fires the server sync
/// only once per provider lifetime so that pull-to-refresh (which calls
/// [refresh]) does not hammer the API on every invalidation.
@Riverpod(keepAlive: true)
class CompletedSessions extends _$CompletedSessions {
  bool _hasSynced = false;

  @override
  Stream<List<WorkoutSessionSummary>> build() {
    if (!_hasSynced) {
      _hasSynced = true;
      _syncInBackground();
    }
    // ref.read — one-shot repository access; no need to re-build this
    // provider when the repository itself is invalidated (e.g. on logout).
    return ref.read(workoutSessionRepositoryProvider).watchCompletedSessions();
  }

  /// Called by pull-to-refresh. Fetches fresh sessions from the server and
  /// upserts them into Drift, which triggers the reactive stream to re-emit.
  /// Network errors are caught so a failed refresh does not crash the UI.
  Future<void> refresh() async {
    try {
      await ref
          .read(workoutSessionRepositoryProvider)
          .syncCompletedSessions();
    } catch (e) {
      debugPrint('CompletedSessions: refresh failed: $e');
    }
  }

  void _syncInBackground() {
    ref
        .read(workoutSessionRepositoryProvider)
        .syncCompletedSessions()
        .catchError((Object e) {
      debugPrint('CompletedSessions: background sync failed: $e');
    });
  }
}

/// Fetches all exercise logs (with nested sets) for a single completed session.
/// Family provider keyed by sessionId — each session's detail is cached
/// independently until the widget holding [SessionDetailScreen] is disposed.
@riverpod
Future<List<ExerciseLog>> sessionExerciseLogs(
    Ref ref, String sessionId) {
  // ref.read — one-shot async fetch; not reactive. The FutureProvider
  // caches the result for the widget's lifetime. Use ref.invalidate to force
  // a refresh (e.g. on retry after an error).
  return ref
      .read(workoutSessionRepositoryProvider)
      .getSessionExerciseLogs(sessionId);
}
