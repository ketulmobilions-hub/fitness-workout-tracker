import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/app_constants.dart';
import '../network/auth_interceptor.dart';
import '../network/error_interceptor.dart';
import '../network/logging_interceptor.dart';
import 'auth_token_provider.dart';

part 'dio_provider.g.dart';

/// Provides the singleton [Dio] HTTP client for the lifetime of the app.
///
/// Interceptors are applied in order:
///   1. [AuthInterceptor] — waits for token to load, then attaches JWT bearer header
///   2. [LoggingInterceptor] — debug-only request/response logging (headers redacted)
///   3. [ErrorInterceptor] — maps errors to typed [AppException]s
///
/// **Testing** — override with a pre-configured [Dio] (or mock):
/// ```dart
/// ProviderScope(
///   overrides: [
///     dioProvider.overrideWithValue(mockDio),
///   ],
///   child: const MyApp(),
/// )
/// ```
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final client = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ),
  );

  client.interceptors.addAll([
    // Async reader: awaits the token future so cold-start requests never
    // go out unauthenticated while AuthTokenNotifier is still loading.
    AuthInterceptor(() => ref.read(authTokenProvider.future)),
    if (kDebugMode) LoggingInterceptor(),
    ErrorInterceptor(),
  ]);

  return client;
}
