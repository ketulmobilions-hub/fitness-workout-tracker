import 'workout_session.dart';

/// Holds the set logs from a single prior completed session for a given exercise.
/// Used to display multi-session history in the previous-performance card.
class PreviousSessionData {
  const PreviousSessionData({
    required this.sessionDate,
    required this.sets,
  });

  /// The date the session was started (local time).
  final DateTime sessionDate;

  /// All sets logged for this exercise in that session, ordered by set number.
  final List<SetLog> sets;

  /// The working set with the highest weight, or null if no working sets exist.
  SetLog? get topWorkingSet {
    final working = sets.where((s) => !s.isWarmup).toList();
    if (working.isEmpty) return null;
    // Bug 4 fix: use strict > so on equal weight the later set (higher index,
    // closer to the end of the session) wins and its RPE/tempo are surfaced.
    return working.reduce((a, b) =>
        (a.weightKg ?? 0) > (b.weightKg ?? 0) ? a : b);
  }
}
