import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/dio_provider.dart';
import '../../workout_history/providers/workout_history_providers.dart';
import '../data/progress_repository_impl.dart';

part 'progress_providers.g.dart';

// Issue #12: marked keepAlive to match actual lifecycle — the repository holds
// a permanent ref.watch dependency on this, so auto-dispose would never fire.
@Riverpod(keepAlive: true)
ProgressApiClient progressApiClient(Ref ref) {
  return ProgressApiClient(ref.watch(dioProvider));
}

@Riverpod(keepAlive: true)
ProgressRepository progressRepository(Ref ref) {
  return ProgressRepositoryImpl(
    apiClient: ref.watch(progressApiClientProvider),
  );
}

// ---------------------------------------------------------------------------
// Overview — streak, total workouts, weekly/monthly volume
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class ProgressOverviewNotifier extends _$ProgressOverviewNotifier {
  @override
  Future<ProgressOverview> build() {
    // Refresh when completedSessionsProvider emits new data — but NOT on the
    // initial AsyncLoading → AsyncData cold-launch transition (which would
    // kick off a second concurrent API request). Also refresh on
    // AsyncError → AsyncData recovery so stale stats are updated after an
    // offline-sync reconnect (Issue #2 follow-up: include AsyncError previous).
    ref.listen(completedSessionsProvider, (previous, next) {
      if ((previous is AsyncData || previous is AsyncError) &&
          next is AsyncData) {
        refresh();
      }
    });
    // ref.watch (not ref.read) so that test overrides of progressRepository
    // are respected and the dependency graph is correctly tracked.
    final utcOffset = DateTime.now().timeZoneOffset.inMinutes;
    return ref.watch(progressRepositoryProvider).fetchOverview(utcOffset);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      // Re-read utcOffset at call time so timezone changes (DST, travel) are
      // picked up on every explicit refresh.
      final utcOffset = DateTime.now().timeZoneOffset.inMinutes;
      final overview =
          await ref.read(progressRepositoryProvider).fetchOverview(utcOffset);
      state = AsyncValue.data(overview);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ---------------------------------------------------------------------------
// Volume trend — period-parameterized
// ---------------------------------------------------------------------------

// Issue #2: use ref.watch so that test overrides of progressRepository are
// respected and the dependency graph is correctly tracked.
@riverpod
Future<VolumeData> volumeData(Ref ref, String period) {
  return ref.watch(progressRepositoryProvider).fetchVolume(period);
}

// ---------------------------------------------------------------------------
// Personal records list
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class PersonalRecordsNotifier extends _$PersonalRecordsNotifier {
  @override
  Future<List<ProgressPersonalRecord>> build() {
    // Same guard as ProgressOverviewNotifier — refresh on Data→Data (new
    // session) and Error→Data (offline recovery), but not on the initial
    // AsyncLoading→AsyncData cold-launch transition.
    ref.listen(completedSessionsProvider, (previous, next) {
      if ((previous is AsyncData || previous is AsyncError) &&
          next is AsyncData) {
        refresh();
      }
    });
    return ref
        .watch(progressRepositoryProvider)
        .fetchPersonalRecords()
        .then(_sortByMostRecent);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final records =
          await ref.read(progressRepositoryProvider).fetchPersonalRecords();
      // Issue #8: sort once at fetch time so _PersonalRecordsList.build()
      // receives a pre-sorted list and never re-sorts on unrelated setState
      // calls (e.g. period chip taps in the parent widget).
      state = AsyncValue.data(_sortByMostRecent(records));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Sort descending by achievedAt using DateTime.tryParse so non-ISO date
  // strings don't corrupt the order (Issue #8 / Issue #12 equivalent for PRs).
  static List<ProgressPersonalRecord> _sortByMostRecent(
    List<ProgressPersonalRecord> records,
  ) {
    return [...records]..sort((a, b) {
      final dtA = DateTime.tryParse(a.achievedAt);
      final dtB = DateTime.tryParse(b.achievedAt);
      if (dtA == null && dtB == null) return 0;
      if (dtA == null) return 1;
      if (dtB == null) return -1;
      return dtB.compareTo(dtA);
    });
  }
}

// ---------------------------------------------------------------------------
// Exercise progress — keyed by (exerciseId, period)
// ---------------------------------------------------------------------------

// Issue #2: ref.watch so repository overrides are respected in tests.
@riverpod
Future<ExerciseProgress> exerciseProgress(
  Ref ref,
  String exerciseId,
  String period,
) {
  return ref
      .watch(progressRepositoryProvider)
      .fetchExerciseProgress(exerciseId, period);
}
