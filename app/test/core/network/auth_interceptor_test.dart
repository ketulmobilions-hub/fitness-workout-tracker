import 'package:dio/dio.dart';
import 'package:fitness_workout_tracker/core/network/auth_interceptor.dart';
import 'package:fitness_workout_tracker/core/providers/auth_token_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthInterceptor', () {
    RequestOptions? capturedOptions;

    setUp(() {
      capturedOptions = null;
    });

    Future<void> runInterceptor(AuthInterceptor interceptor) async {
      final options = RequestOptions(path: '/test');
      await interceptor.onRequest(
        options,
        _CapturingRequestHandler((opts) => capturedOptions = opts),
      );
    }

    test('injects Authorization header when token is present', () async {
      final interceptor = AuthInterceptor(
        () => Future.value(const AuthToken(accessToken: 'test-jwt')),
      );
      await runInterceptor(interceptor);

      expect(capturedOptions!.headers['Authorization'], 'Bearer test-jwt');
    });

    test('does not inject Authorization header when token is null', () async {
      final interceptor = AuthInterceptor(() => Future.value(null));
      await runInterceptor(interceptor);

      expect(capturedOptions!.headers.containsKey('Authorization'), isFalse);
    });

    test('proceeds without header when token reader throws', () async {
      final interceptor = AuthInterceptor(
        () => Future.error(Exception('storage error')),
      );
      await runInterceptor(interceptor);

      // Request should still proceed — no auth header, no exception thrown
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.headers.containsKey('Authorization'), isFalse);
    });
  });
}

/// Captures the options passed to handler.next.
class _CapturingRequestHandler extends RequestInterceptorHandler {
  _CapturingRequestHandler(this._onNext);

  final void Function(RequestOptions) _onNext;

  @override
  void next(RequestOptions requestOptions) => _onNext(requestOptions);
}
