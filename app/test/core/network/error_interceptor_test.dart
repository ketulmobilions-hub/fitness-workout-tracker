import 'package:dio/dio.dart';
import 'package:fitness_workout_tracker/core/errors/app_exception.dart';
import 'package:fitness_workout_tracker/core/network/error_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ErrorInterceptor interceptor;

  setUp(() {
    interceptor = ErrorInterceptor();
  });

  DioException makeError({
    DioExceptionType type = DioExceptionType.badResponse,
    int? statusCode,
    Map<String, dynamic>? body,
  }) {
    return DioException(
      requestOptions: RequestOptions(path: '/test'),
      type: type,
      response: statusCode != null
          ? Response<dynamic>(
              requestOptions: RequestOptions(path: '/test'),
              statusCode: statusCode,
              data: body,
            )
          : null,
    );
  }

  AppException captureError(DioException err) {
    AppException? captured;
    interceptor.onError(
      err,
      _CapturingErrorHandler((e) => captured = e.error as AppException),
    );
    return captured!;
  }

  group('ErrorInterceptor', () {
    test('maps connectionError to NetworkException', () {
      expect(
        captureError(makeError(type: DioExceptionType.connectionError)),
        isA<NetworkException>(),
      );
    });

    test('maps connectionTimeout to NetworkException', () {
      expect(
        captureError(makeError(type: DioExceptionType.connectionTimeout)),
        isA<NetworkException>(),
      );
    });

    test('maps cancel to CancelledException', () {
      expect(
        captureError(makeError(type: DioExceptionType.cancel)),
        isA<CancelledException>(),
      );
    });

    test('maps 401 to UnauthorizedException', () {
      expect(captureError(makeError(statusCode: 401)), isA<UnauthorizedException>());
    });

    test('maps 422 to ValidationException', () {
      expect(captureError(makeError(statusCode: 422)), isA<ValidationException>());
    });

    test('maps 422 with details to ValidationException with fields', () {
      final err = makeError(
        statusCode: 422,
        body: {
          'message': 'Validation failed',
          'details': [
            {'field': 'email', 'message': 'must be a valid email'},
            {'field': 'email', 'message': 'already taken'},
          ],
        },
      );
      final exception = captureError(err) as ValidationException;
      // Both messages must be present — Map<String, List<String>> collects all
      expect(exception.fields!['email'], containsAll(['must be a valid email', 'already taken']));
    });

    test('maps 500 to ServerException with correct status code', () {
      final exception = captureError(makeError(statusCode: 500)) as ServerException;
      expect(exception.statusCode, 500);
    });

    test('maps 404 to ServerException', () {
      expect(captureError(makeError(statusCode: 404)), isA<ServerException>());
    });

    test('maps no-response unknown error to UnknownException', () {
      expect(
        captureError(makeError(type: DioExceptionType.unknown)),
        isA<UnknownException>(),
      );
    });

    test('extracts message from response body', () {
      final err = makeError(
        statusCode: 500,
        body: {'message': 'Internal Server Error'},
      );
      final exception = captureError(err) as ServerException;
      expect(exception.message, 'Internal Server Error');
    });
  });
}

class _CapturingErrorHandler extends ErrorInterceptorHandler {
  _CapturingErrorHandler(this._onNext);

  final void Function(DioException) _onNext;

  @override
  void next(DioException err) => _onNext(err);
}
