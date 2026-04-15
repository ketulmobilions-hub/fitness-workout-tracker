import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'workout_plan_providers.dart';

part 'plan_detail_provider.g.dart';

@riverpod
class PlanDetail extends _$PlanDetail {
  bool _hasSynced = false;

  @override
  Stream<WorkoutPlan?> build(String planId) {
    if (!_hasSynced) {
      _hasSynced = true;
      _syncInBackground(planId);
    }
    return ref.watch(workoutPlanRepositoryProvider).watchPlan(planId);
  }

  /// Called by pull-to-refresh or the error-state retry button. Errors are
  /// caught so a network failure does not kill the Drift stream.
  Future<void> refresh() async {
    try {
      await ref.read(workoutPlanRepositoryProvider).syncPlanDetail(planId);
    } catch (e) {
      debugPrint('PlanDetail: refresh failed for $planId: $e');
    }
  }

  void _syncInBackground(String planId) {
    ref
        .read(workoutPlanRepositoryProvider)
        .syncPlanDetail(planId)
        .catchError((Object e) {
      debugPrint('PlanDetail: background sync failed for $planId: $e');
    });
  }
}
