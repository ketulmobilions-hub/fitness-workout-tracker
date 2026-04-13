import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../errors/app_exception.dart';
import 'flutter_secure_storage_provider.dart';

part 'auth_token_provider.freezed.dart';
part 'auth_token_provider.g.dart';

const _kAccessTokenKey = 'access_token';
const _kRefreshTokenKey = 'refresh_token';

@freezed
sealed class AuthToken with _$AuthToken {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory AuthToken({
    required String accessToken,
    String? refreshToken,
  }) = _AuthToken;

  factory AuthToken.fromJson(Map<String, dynamic> json) =>
      _$AuthTokenFromJson(json);
}

/// Manages JWT access and refresh tokens, persisted in secure storage.
///
/// Usage:
/// ```dart
/// // Read current token (null when not logged in)
/// final token = ref.watch(authTokenProvider).value;
///
/// // Set tokens after login
/// await ref.read(authTokenProvider.notifier).setTokens(
///   AuthToken(accessToken: '...', refreshToken: '...'),
/// );
///
/// // Clear tokens on logout
/// await ref.read(authTokenProvider.notifier).clearTokens();
/// ```
@Riverpod(keepAlive: true)
class AuthTokenNotifier extends _$AuthTokenNotifier {
  @override
  Future<AuthToken?> build() async {
    final storage = ref.read(flutterSecureStorageProvider);
    final accessToken = await storage.read(key: _kAccessTokenKey);
    if (accessToken == null) return null;
    final refreshToken = await storage.read(key: _kRefreshTokenKey);
    return AuthToken(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> setTokens(AuthToken token) async {
    try {
      final storage = ref.read(flutterSecureStorageProvider);
      await storage.write(key: _kAccessTokenKey, value: token.accessToken);
      // Always sync the refresh token key — write or delete — so storage and
      // in-memory state never diverge.
      if (token.refreshToken != null) {
        await storage.write(
          key: _kRefreshTokenKey,
          value: token.refreshToken,
        );
      } else {
        await storage.delete(key: _kRefreshTokenKey);
      }
      state = AsyncData(token);
    } catch (e) {
      throw AppException.unknown(message: 'Failed to persist tokens: $e');
    }
  }

  Future<void> clearTokens() async {
    try {
      final storage = ref.read(flutterSecureStorageProvider);
      await storage.delete(key: _kAccessTokenKey);
      await storage.delete(key: _kRefreshTokenKey);
      state = const AsyncData(null);
    } catch (e) {
      throw AppException.unknown(message: 'Failed to clear tokens: $e');
    }
  }
}
