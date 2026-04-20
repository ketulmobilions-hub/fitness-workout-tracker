import 'package:fitness_data/fitness_data.dart' as data;
import 'package:fitness_domain/fitness_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/dio_provider.dart';
import '../../workout_history/providers/workout_history_providers.dart';
import '../../workout_plans/providers/workout_plan_providers.dart';
import '../data/streak_repository_impl.dart';

part 'streak_providers.g.dart';

@Riverpod(keepAlive: true)
data.StreakApiClient streakApiClient(Ref ref) {
  return data.StreakApiClient(ref.watch(dioProvider));
}

@Riverpod(keepAlive: true)
StreakRepository streakRepository(Ref ref) {
  return StreakRepositoryImpl(
    apiClient: ref.watch(streakApiClientProvider),
    progressDao: ref.watch(appDatabaseProvider).progressDao,
  );
}

// ---------------------------------------------------------------------------
// Current streak — Drift-backed stream (offline-first)
// ---------------------------------------------------------------------------

/// Watches the local Drift streak row and kicks off a background network
/// refresh. The stream emits immediately from cache (null if no local data
/// yet) and updates again when the refresh writes to Drift.
@Riverpod(keepAlive: true)
Stream<Streak?> streakStream(Ref ref) {
  final userId = ref.watch(stableUserIdProvider) ?? '';
  final repo = ref.watch(streakRepositoryProvider);

  // Refresh when a session completes so the streak reflects the new workout.
  ref.listen(completedSessionsProvider, (previous, next) {
    if ((previous is AsyncData || previous is AsyncError) &&
        next is AsyncData) {
      if (userId.isNotEmpty) repo.refreshStreak(userId).ignore();
    }
  });

  if (userId.isNotEmpty) repo.refreshStreak(userId).ignore();
  return repo.watchStreak(userId);
}

// ---------------------------------------------------------------------------
// Month streak history — parameterized by (year, month)
// ---------------------------------------------------------------------------

@riverpod
Stream<List<StreakDay>> streakHistory(Ref ref, int year, int month) {
  final userId = ref.watch(stableUserIdProvider) ?? '';
  final repo = ref.watch(streakRepositoryProvider);

  if (userId.isNotEmpty) {
    repo.refreshStreakHistory(userId, year, month).ignore();
  }

  final since = DateTime.utc(year, month, 1);
  return repo.watchStreakHistory(userId, since: since).map(
        (days) => days
            .where((d) => _isInMonth(d.date, year, month))
            .toList(),
      );
}

bool _isInMonth(String yyyyMmDd, int year, int month) {
  final parts = yyyyMmDd.split('-');
  if (parts.length < 2) return false;
  return int.tryParse(parts[0]) == year && int.tryParse(parts[1]) == month;
}

// ---------------------------------------------------------------------------
// Milestone tracking — in-memory per session
// ---------------------------------------------------------------------------

const kStreakMilestones = [7, 30, 100, 365];

@riverpod
class MilestoneNotifier extends _$MilestoneNotifier {
  @override
  int? build() => null;

  /// Checks if [currentStreak] has reached a new (uncelebrated) milestone and
  /// updates state. Call this every time fresh streak data arrives. The UI
  /// listens and shows a celebration dialog exactly once per milestone per
  /// session.
  void maybeUnlock(int currentStreak) {
    // Find the highest milestone reached that is greater than what was last celebrated.
    int newMilestone = -1;
    for (final m in kStreakMilestones) {
      if (currentStreak >= m && (state == null || state! < m)) {
        newMilestone = m;
      }
    }
    if (newMilestone != -1) state = newMilestone;
  }
}
