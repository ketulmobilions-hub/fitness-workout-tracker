import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'workout_plan_providers.dart';

part 'plan_list_provider.g.dart';

@riverpod
class PlanList extends _$PlanList {
  // Guards against re-triggering sync on every build() call. build() is
  // re-invoked whenever any watched dependency changes. The flag resets when
  // the notifier is disposed and re-created (e.g. navigating away and back).
  bool _hasSynced = false;

  @override
  Stream<List<WorkoutPlan>> build() {
    if (!_hasSynced) {
      _hasSynced = true;
      _syncInBackground();
    }
    return ref.watch(workoutPlanRepositoryProvider).watchPlans();
  }

  /// Called by pull-to-refresh. Errors are caught so a network failure during
  /// refresh does not kill the Drift stream (which still emits cached data).
  Future<void> refresh() async {
    try {
      await ref.read(workoutPlanRepositoryProvider).syncPlans();
    } catch (e) {
      debugPrint('PlanList: refresh failed: $e');
    }
  }

  void _syncInBackground() {
    ref
        .read(workoutPlanRepositoryProvider)
        .syncPlans()
        .catchError((Object e) {
      debugPrint('PlanList: background sync failed: $e');
    });
  }
}
