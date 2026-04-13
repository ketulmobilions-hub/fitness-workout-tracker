import 'package:dio/dio.dart';

import '../providers/auth_token_provider.dart';

/// Attaches the JWT access token to every outgoing request.
///
/// Accepts an async [tokenReader] callback so the interceptor waits for
/// the token to finish loading from secure storage before sending the request.
/// This prevents unauthenticated requests during app startup when
/// [AuthTokenNotifier] is still building.
///
/// Example:
/// ```dart
/// AuthInterceptor(() => ref.read(authTokenProvider.future))
/// ```
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenReader);

  final Future<AuthToken?> Function() _tokenReader;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _tokenReader();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer ${token.accessToken}';
      }
    } catch (_) {
      // If token loading fails, proceed without auth header rather than
      // blocking the request indefinitely.
    }
    handler.next(options);
  }
}
