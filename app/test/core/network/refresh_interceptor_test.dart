import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fitness_workout_tracker/core/network/refresh_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Error-interceptor handler that captures resolve / next calls without
/// propagating to a real interceptor chain.
class _CapturingErrorHandler extends ErrorInterceptorHandler {
  Response<dynamic>? resolvedWith;
  DioException? nextedWith;

  @override
  void resolve(Response<dynamic> response) => resolvedWith = response;

  @override
  void next(DioException err) => nextedWith = err;
}

/// Minimal Dio stub that only implements [fetch] — everything else throws
/// [UnimplementedError] if accidentally called. Using [noSuchMethod] avoids
/// having to provide concrete implementations for all abstract [Dio] members.
class _StubDio implements Dio {
  /// Called per [fetch] invocation. Set to return a success response,
  /// throw a [DioException], or throw any other exception.
  Future<Response<dynamic>> Function(RequestOptions)? onFetch;

  final List<RequestOptions> capturedOptions = [];

  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) async {
    capturedOptions.add(requestOptions);
    if (onFetch != null) {
      // Let the callback decide — may throw.
      final resp = await onFetch!(requestOptions);
      return Response<T>(
        requestOptions: resp.requestOptions,
        data: resp.data as T?,
        statusCode: resp.statusCode,
      );
    }
    return Response<T>(requestOptions: requestOptions, statusCode: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not needed in RefreshInterceptor tests',
    );
  }
}

// ---------------------------------------------------------------------------
// Factory helpers
// ---------------------------------------------------------------------------

DioException _make401({String path = '/api/data'}) {
  final opts = RequestOptions(path: path);
  return DioException(
    requestOptions: opts,
    response: Response(requestOptions: opts, statusCode: 401),
    type: DioExceptionType.badResponse,
  );
}

DioException _make404() {
  final opts = RequestOptions(path: '/api/data');
  return DioException(
    requestOptions: opts,
    response: Response(requestOptions: opts, statusCode: 404),
    type: DioExceptionType.badResponse,
  );
}

Response<dynamic> _successResponse(RequestOptions opts) =>
    Response<dynamic>(requestOptions: opts, statusCode: 200);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _StubDio innerDio;
  late int refreshCallCount;
  late int refreshFailedCallCount;
  late String? currentAccessToken;

  setUp(() {
    innerDio = _StubDio();
    refreshCallCount = 0;
    refreshFailedCallCount = 0;
    currentAccessToken = 'new-token';
  });

  RefreshInterceptor makeInterceptor({
    Future<void> Function()? onRefresh,
    Future<void> Function()? onRefreshFailed,
    Future<String?> Function()? newAccessTokenReader,
  }) {
    return RefreshInterceptor(
      innerDio: innerDio,
      onRefresh: onRefresh ??
          () async {
            refreshCallCount++;
          },
      onRefreshFailed: onRefreshFailed ??
          () async {
            refreshFailedCallCount++;
          },
      newAccessTokenReader:
          newAccessTokenReader ?? () async => currentAccessToken,
    );
  }

  // -------------------------------------------------------------------------
  // Pass-through: errors that must NOT trigger refresh
  // -------------------------------------------------------------------------
  group('pass-through (no refresh)', () {
    test('non-401 error is forwarded unchanged', () async {
      final interceptor = makeInterceptor();
      final handler = _CapturingErrorHandler();

      await interceptor.onError(_make404(), handler);

      expect(refreshCallCount, 0);
      expect(handler.nextedWith, isNotNull);
      expect(handler.nextedWith!.response!.statusCode, 404);
    });

    test('/auth/refresh 401 is forwarded to break refresh recursion', () async {
      final interceptor = makeInterceptor();
      final handler = _CapturingErrorHandler();
      final err = _make401(path: '/auth/refresh');

      await interceptor.onError(err, handler);

      expect(refreshCallCount, 0);
      expect(handler.nextedWith, isNotNull);
    });

    test('already-retried request is forwarded without another refresh', () async {
      final interceptor = makeInterceptor();
      final handler = _CapturingErrorHandler();
      final opts = RequestOptions(
        path: '/api/data',
        extra: {'_retried': true},
      );
      final err = DioException(
        requestOptions: opts,
        response: Response(requestOptions: opts, statusCode: 401),
        type: DioExceptionType.badResponse,
      );

      await interceptor.onError(err, handler);

      expect(refreshCallCount, 0);
      expect(handler.nextedWith, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Happy path: refresh succeeds, retry succeeds
  // -------------------------------------------------------------------------
  group('refresh success → retry success', () {
    test('resolves handler with the retried response', () async {
      innerDio.onFetch = (opts) async => _successResponse(opts);
      final interceptor = makeInterceptor();
      final handler = _CapturingErrorHandler();

      await interceptor.onError(_make401(), handler);

      expect(refreshCallCount, 1);
      expect(handler.resolvedWith, isNotNull);
      expect(handler.resolvedWith!.statusCode, 200);
      expect(handler.nextedWith, isNull);
    });

    test('retry request carries the updated Authorization header', () async {
      innerDio.onFetch = (opts) async => _successResponse(opts);
      final interceptor = makeInterceptor();
      final handler = _CapturingErrorHandler();

      await interceptor.onError(_make401(), handler);

      expect(
        innerDio.capturedOptions.single.headers['Authorization'],
        'Bearer new-token',
      );
    });

    test('retry request has _retried flag set', () async {
      innerDio.onFetch = (opts) async => _successResponse(opts);
      final interceptor = makeInterceptor();
      final handler = _CapturingErrorHandler();

      await interceptor.onError(_make401(), handler);

      expect(innerDio.capturedOptions.single.extra['_retried'], isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Retry fails after refresh
  // -------------------------------------------------------------------------
  group('refresh success → retry failure', () {
    test('forwards DioException when inner dio throws on retry', () async {
      innerDio.onFetch = (opts) async {
        throw DioException(
          requestOptions: opts,
          response: Response(requestOptions: opts, statusCode: 403),
          type: DioExceptionType.badResponse,
        );
      };
      final interceptor = makeInterceptor();
      final handler = _CapturingErrorHandler();

      await interceptor.onError(_make401(), handler);

      expect(refreshCallCount, 1);
      expect(handler.resolvedWith, isNull);
      expect(handler.nextedWith, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Refresh fails
  // -------------------------------------------------------------------------
  group('refresh failure', () {
    test('calls onRefreshFailed and forwards original 401', () async {
      final interceptor = makeInterceptor(
        onRefresh: () async => throw Exception('refresh failed'),
      );
      final handler = _CapturingErrorHandler();

      await interceptor.onError(_make401(), handler);

      expect(refreshFailedCallCount, 1);
      expect(handler.nextedWith, isNotNull);
      expect(handler.nextedWith!.response?.statusCode, 401);
    });

    test('does not call innerDio.fetch when refresh fails', () async {
      final interceptor = makeInterceptor(
        onRefresh: () async => throw Exception('refresh failed'),
      );

      await interceptor.onError(_make401(), _CapturingErrorHandler());

      expect(innerDio.capturedOptions, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Concurrent 401s — only one refresh issued
  // -------------------------------------------------------------------------
  group('concurrent 401s', () {
    test('refresh is issued once; all queued requests are replayed on success',
        () async {
      final refreshCompleter = Completer<void>();
      var refreshCount = 0;

      innerDio.onFetch = (opts) async => _successResponse(opts);

      final interceptor = makeInterceptor(
        onRefresh: () async {
          refreshCount++;
          await refreshCompleter.future;
        },
      );

      final handler1 = _CapturingErrorHandler();
      final handler2 = _CapturingErrorHandler();

      // Start first 401 — pauses at refreshCompleter.
      final f1 = interceptor.onError(_make401(path: '/api/a'), handler1);

      // Second 401 arrives while first is still refreshing — queued.
      final f2 = interceptor.onError(_make401(path: '/api/b'), handler2);

      // Allow refresh to complete.
      refreshCompleter.complete();
      await Future.wait([f1, f2]);

      expect(refreshCount, 1);
      expect(handler1.resolvedWith, isNotNull);
      expect(handler2.resolvedWith, isNotNull);
      // Two fetch calls: one retry for each 401.
      expect(innerDio.capturedOptions.length, 2);
    });

    test('refresh fails: onRefreshFailed called once; all queued get 401',
        () async {
      final refreshCompleter = Completer<void>();
      var refreshFailedCount = 0;

      final interceptor = makeInterceptor(
        onRefresh: () async {
          await refreshCompleter.future;
          throw Exception('token revoked');
        },
        onRefreshFailed: () async => refreshFailedCount++,
      );

      final handler1 = _CapturingErrorHandler();
      final handler2 = _CapturingErrorHandler();
      final handler3 = _CapturingErrorHandler();

      final f1 = interceptor.onError(_make401(path: '/api/a'), handler1);
      final f2 = interceptor.onError(_make401(path: '/api/b'), handler2);
      final f3 = interceptor.onError(_make401(path: '/api/c'), handler3);

      refreshCompleter.complete();
      await Future.wait([f1, f2, f3]);

      expect(refreshFailedCount, 1);
      // All handlers should have a DioException forwarded, not a resolve.
      expect(handler1.resolvedWith, isNull);
      expect(handler2.resolvedWith, isNull);
      expect(handler3.resolvedWith, isNull);
      expect(handler1.nextedWith, isNotNull);
      expect(handler2.nextedWith, isNotNull);
      expect(handler3.nextedWith, isNotNull);
      // No fetch calls — refresh failed before retries.
      expect(innerDio.capturedOptions, isEmpty);
    });

    test('queued request DioException carries original 401 response metadata',
        () async {
      final refreshCompleter = Completer<void>();

      final opts = RequestOptions(path: '/api/b');
      final originalResponse = Response<dynamic>(
        requestOptions: opts,
        statusCode: 401,
        data: {'error': 'token_expired'},
      );
      final queued401 = DioException(
        requestOptions: opts,
        response: originalResponse,
        type: DioExceptionType.badResponse,
      );

      final interceptor = makeInterceptor(
        onRefresh: () async {
          await refreshCompleter.future;
          throw Exception('failed');
        },
        onRefreshFailed: () async {},
      );

      final handler1 = _CapturingErrorHandler();
      final handlerQueued = _CapturingErrorHandler();

      final f1 = interceptor.onError(_make401(path: '/api/a'), handler1);
      final f2 = interceptor.onError(queued401, handlerQueued);

      refreshCompleter.complete();
      await Future.wait([f1, f2]);

      // The queued handler should receive a DioException whose response has
      // the original 401 status so callers can distinguish auth errors.
      expect(handlerQueued.nextedWith?.response?.statusCode, 401);
    });
  });

  // -------------------------------------------------------------------------
  // Null access token after refresh
  // -------------------------------------------------------------------------
  group('null access token after refresh', () {
    test(
        'retry is attempted with "Bearer null" header when newAccessTokenReader '
        'returns null — documents the known edge-case behavior',
        () async {
      // In practice this should not happen: if onRefresh() succeeds the token
      // store should always have a new token. But if it somehow returns null
      // (e.g. a race that clears tokens concurrently), the retry proceeds with
      // an invalid Authorization header, which the server will reject with 401.
      innerDio.onFetch = (opts) async => _successResponse(opts);

      final interceptor = RefreshInterceptor(
        innerDio: innerDio,
        onRefresh: () async => refreshCallCount++,
        onRefreshFailed: () async => refreshFailedCallCount++,
        newAccessTokenReader: () async => null,
      );
      final handler = _CapturingErrorHandler();

      await interceptor.onError(_make401(), handler);

      expect(refreshCallCount, 1);
      // The retry still fires — the interceptor does not treat a null token as
      // a refresh failure. The server will reject the request with its own 401.
      expect(innerDio.capturedOptions.length, 1);
      expect(
        innerDio.capturedOptions.single.headers['Authorization'],
        'Bearer null',
      );
    });
  });

  // -------------------------------------------------------------------------
  // State reset after handling
  // -------------------------------------------------------------------------
  group('state reset', () {
    test('interceptor can handle a second 401 after a completed refresh cycle',
        () async {
      int refreshCount = 0;
      innerDio.onFetch = (opts) async => _successResponse(opts);

      final interceptor = makeInterceptor(
        onRefresh: () async => refreshCount++,
      );

      // First 401.
      final handler1 = _CapturingErrorHandler();
      await interceptor.onError(_make401(), handler1);
      expect(refreshCount, 1);
      expect(handler1.resolvedWith, isNotNull);

      // Second 401 — should trigger a fresh refresh, not get queued.
      final handler2 = _CapturingErrorHandler();
      await interceptor.onError(_make401(), handler2);
      expect(refreshCount, 2);
      expect(handler2.resolvedWith, isNotNull);
    });
  });
}
