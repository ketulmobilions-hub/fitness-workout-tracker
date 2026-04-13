import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/app_constants.dart';
import '../network/auth_interceptor.dart';
import '../network/error_interceptor.dart';
import '../network/logging_interceptor.dart';
import '../network/refresh_interceptor.dart';
import 'auth_token_provider.dart';

part 'dio_provider.g.dart';

/// Provides the singleton [Dio] HTTP client for the lifetime of the app.
///
/// Interceptors are applied in order:
///   1. [AuthInterceptor]    — waits for token to load, attaches JWT bearer header
///   2. [LoggingInterceptor] — debug-only request/response logging (headers redacted)
///   3. [ErrorInterceptor]   — maps errors to typed [AppException]s
///   4. [RefreshInterceptor] — on 401: refreshes token then retries original request
///
/// The [RefreshInterceptor] uses an **inner** [Dio] (same base options, without
/// [RefreshInterceptor]) to call `/auth/refresh` directly, avoiding the circular
/// dependency that would exist if it called [authRepositoryProvider].
///
/// **Testing** — override with a pre-configured [Dio] (or mock):
/// ```dart
/// ProviderScope(
///   overrides: [dioProvider.overrideWithValue(mockDio)],
///   child: const MyApp(),
/// )
/// ```
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final baseOptions = BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  );

  // Inner Dio: used ONLY for the /auth/refresh call.
  // Does NOT include RefreshInterceptor to prevent infinite recursion.
  final innerDio = Dio(baseOptions)
    ..interceptors.addAll([
      AuthInterceptor(() => ref.read(authTokenProvider.future)),
      if (kDebugMode) LoggingInterceptor(),
      ErrorInterceptor(),
    ]);

  final client = Dio(baseOptions)
    ..interceptors.addAll([
      AuthInterceptor(() => ref.read(authTokenProvider.future)),
      if (kDebugMode) LoggingInterceptor(),
      ErrorInterceptor(),
      RefreshInterceptor(
        innerDio: innerDio,
        onRefresh: () => _refreshTokens(ref, innerDio),
        onRefreshFailed: () => ref.read(authTokenProvider.notifier).clearTokens(),
        newAccessTokenReader: () async {
          final token = await ref.read(authTokenProvider.future);
          return token?.accessToken;
        },
      ),
    ]);

  return client;
}

/// Calls /auth/refresh via [innerDio] and persists the new tokens.
/// Extracted here so it is not a closure capturing mutable state.
Future<void> _refreshTokens(Ref ref, Dio innerDio) async {
  final current = await ref.read(authTokenProvider.future);
  if (current?.refreshToken == null) {
    throw Exception('No refresh token available');
  }

  final response = await innerDio.post<Map<String, dynamic>>(
    '/auth/refresh',
    data: {'refreshToken': current!.refreshToken},
  );

  final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
  final accessToken = data['accessToken'] as String?;
  final refreshToken = data['refreshToken'] as String?;

  if (accessToken == null || refreshToken == null) {
    throw Exception('Refresh response missing tokens');
  }

  await ref.read(authTokenProvider.notifier).setTokens(
        AuthToken(accessToken: accessToken, refreshToken: refreshToken),
      );
}
