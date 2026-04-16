import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/dio_provider.dart';
import '../../workout_plans/providers/workout_plan_providers.dart';
import '../data/workout_session_repository_impl.dart';

part 'active_session_providers.g.dart';

@riverpod
SessionApiClient sessionApiClient(Ref ref) {
  return SessionApiClient(ref.watch(dioProvider));
}

/// Recreated only when the authenticated user ID changes. Reuses
/// [stableUserIdProvider] defined in the workout_plans feature to avoid
/// duplicate keepAlive providers tracking the same auth state.
///
/// ── Fix #6: pass an empty userId only as a last resort. The repository impl
/// guards against empty-userId writes (throws [StateError] in startSession),
/// preventing invalid FK rows while auth is initializing or transitioning.
@Riverpod(keepAlive: true)
WorkoutSessionRepository workoutSessionRepository(Ref ref) {
  final userId = ref.watch(stableUserIdProvider) ?? '';
  return WorkoutSessionRepositoryImpl(
    apiClient: ref.watch(sessionApiClientProvider),
    sessionDao: ref.watch(appDatabaseProvider).workoutSessionDao,
    userId: userId,
  );
}

/// Stream of the currently active (in-progress) session, or null when the user
/// has no workout running. Stays alive so the app can surface a "resume
/// workout" prompt from any screen.
@Riverpod(keepAlive: true)
Stream<WorkoutSession?> activeSessionStream(Ref ref) {
  return ref.watch(workoutSessionRepositoryProvider).watchActiveSession();
}
