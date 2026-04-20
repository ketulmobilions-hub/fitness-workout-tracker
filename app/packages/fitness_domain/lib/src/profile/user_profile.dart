import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_preferences.dart';

part 'user_profile.freezed.dart';

enum UserAuthProvider { emailPassword, google, apple, guest }

@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? bio,
    required UserAuthProvider authProvider,
    required bool isGuest,
    required UserPreferences preferences,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserProfile;
}
