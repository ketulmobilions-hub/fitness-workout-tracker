import 'package:fitness_data/fitness_data.dart' as data;
import 'package:fitness_domain/fitness_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/auth_token_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/dio_provider.dart';
import '../../workout_plans/providers/workout_plan_providers.dart';
import '../data/profile_repository_impl.dart';

part 'profile_providers.g.dart';

// Issue #17: keepAlive: true prevents profileRepositoryProvider (also keepAlive)
// from holding a reference to a stale, auto-disposed Dio client after a route
// transition. Without keepAlive the interceptors (auth header injection) clear,
// causing subsequent API calls to go out without an Authorization header.
@Riverpod(keepAlive: true)
data.UserApiClient userApiClient(Ref ref) {
  return data.UserApiClient(ref.watch(dioProvider));
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepositoryImpl(
    apiClient: ref.watch(userApiClientProvider),
    userDao: ref.watch(appDatabaseProvider).userDao,
    clearTokens: () => ref.read(authTokenProvider.notifier).clearTokens(),
  );
}

/// Tracks the error (if any) from the most recent background profile refresh.
/// The UI reads this to decide whether to show a retry message when the local
/// Drift cache is empty and the network call also failed (Issue #7).
@Riverpod(keepAlive: true)
class ProfileRefreshError extends _$ProfileRefreshError {
  @override
  String? build() => null;

  void set(String message) => state = message;
  void clear() => state = null;
}

/// Streams the current user's profile from local Drift DB, keeping it fresh
/// with a background server refresh when the user ID is known.
@Riverpod(keepAlive: true)
Stream<UserProfile?> profileStream(Ref ref) {
  final userId = ref.watch(stableUserIdProvider);

  // Issue #6: guard null/empty userId — avoids a real SQLite query with
  // an empty-string ID during unauthenticated / initializing auth states.
  if (userId == null || userId.isEmpty) return Stream.value(null);

  final repo = ref.watch(profileRepositoryProvider);

  // Issue #7: propagate refresh errors through a separate notifier so the UI
  // can show an actionable message when both the cache and network are unavailable.
  repo.refreshProfile(userId).then(
    (_) => ref.read(profileRefreshErrorProvider.notifier).clear(),
    onError: (Object e) =>
        ref.read(profileRefreshErrorProvider.notifier).set(e.toString()),
  );

  return repo.watchProfile(userId);
}

/// Live stats from the server — not cached locally.
@riverpod
Future<UserStats> userStats(Ref ref) async {
  return ref.watch(profileRepositoryProvider).getStats();
}
