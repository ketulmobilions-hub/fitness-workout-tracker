import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'exercise_filter_provider.dart';
import 'exercise_providers.dart';

part 'exercise_list_provider.g.dart';

@riverpod
class ExerciseList extends _$ExerciseList {
  // Guards against re-triggering sync on every build() call. build() is
  // re-invoked whenever any watched dependency changes (e.g. filter state on
  // every keystroke). The flag is reset when the notifier is disposed and
  // re-created (e.g. navigating away and back), triggering a fresh sync.
  bool _hasSynced = false;

  @override
  Stream<List<Exercise>> build() {
    if (!_hasSynced) {
      _hasSynced = true;
      _syncInBackground();
    }

    final filter = ref.watch(exerciseFilterProvider);
    return ref.watch(exerciseRepositoryProvider).watchExercises(
          search: filter.search.isEmpty ? null : filter.search,
          type: filter.type,
          muscleGroupName: filter.muscleGroupName,
        );
  }

  /// Called by pull-to-refresh. Errors are caught so a network failure during
  /// refresh does not kill the Drift stream (which still emits cached data).
  Future<void> refresh() async {
    try {
      await ref.read(exerciseRepositoryProvider).syncExercises();
    } catch (e) {
      // Sync failed (e.g. offline). The stream continues to emit cached data.
      // Swallowing here keeps RefreshIndicator's spinner from hanging; the
      // "Could not load" error state is only shown when the stream itself is
      // empty AND errored, which requires the Drift DB to also fail.
      debugPrint('ExerciseList: refresh failed: $e');
    }
  }

  void _syncInBackground() {
    ref
        .read(exerciseRepositoryProvider)
        .syncExercises()
        .catchError((Object e) {
      debugPrint('ExerciseList: background sync failed: $e');
    });
  }
}
