import 'user_preferences.dart';
import 'user_profile.dart';
import 'user_stats.dart';

abstract interface class ProfileRepository {
  /// Streams the local profile, kept in sync with the server on each call.
  Stream<UserProfile?> watchProfile(String userId);

  /// Fetches profile from server and updates local cache.
  Future<UserProfile> refreshProfile(String userId);

  /// Updates display name, avatar URL, or bio. At least one must be non-null.
  Future<UserProfile> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? bio,
  });

  /// Merges preference changes to the server and updates local cache for [userId].
  Future<UserPreferences> updatePreferences(
      String userId, UserPreferences prefs);

  /// Fetches live stats from the server (not cached locally).
  Future<UserStats> getStats();

  /// Deletes account on server and clears all local user data for [userId].
  Future<void> deleteAccount(String userId);
}
