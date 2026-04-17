import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/dio_provider.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../auth/providers/auth_state.dart';
import '../data/workout_plan_repository_impl.dart';

part 'workout_plan_providers.g.dart';

@riverpod
PlanApiClient planApiClient(Ref ref) {
  return PlanApiClient(ref.watch(dioProvider));
}

/// Derives a stable user ID from auth state, emitting null for any transient
/// or unauthenticated state. By depending on THIS provider instead of
/// [authProvider] directly, [workoutPlanRepositoryProvider] only rebuilds
/// when the identity actually changes — not on every intermediate AuthLoading
/// or AuthInitializing transition.
///
/// keepAlive: true is required. Without it the provider is auto-disposed
/// between route transitions, causing it to momentarily re-emit null and
/// triggering an unnecessary rebuild of [workoutPlanRepositoryProvider].
@Riverpod(keepAlive: true)
String? stableUserId(Ref ref) {
  return switch (ref.watch(authProvider)) {
    Authenticated(:final user) => user.id,
    AuthGuest(:final user) => user.id,
    _ => null,
  };
}

/// Recreated only when the authenticated user ID changes (login/logout/switch).
/// Returns a no-op stub repository while [stableUserId] is null so that callers
/// never receive a repository scoped to an empty string.
@Riverpod(keepAlive: true)
WorkoutPlanRepository workoutPlanRepository(Ref ref) {
  final userId = ref.watch(stableUserIdProvider) ?? '';
  return WorkoutPlanRepositoryImpl(
    apiClient: ref.watch(planApiClientProvider),
    planDao: ref.watch(appDatabaseProvider).workoutPlanDao,
    syncQueueDao: ref.watch(appDatabaseProvider).syncQueueDao,
    userId: userId,
  );
}
