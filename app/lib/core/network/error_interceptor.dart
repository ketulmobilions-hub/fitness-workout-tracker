import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// Maps [DioException] types and HTTP status codes to typed [AppException]s.
///
/// The [AppException] is stored in [DioException.error] so callers can
/// pattern-match on it:
/// ```dart
/// on DioException catch (e) {
///   switch (e.error) {
///     case UnauthorizedException(): ...
///     case CancelledException(): return; // ignore
///     case NetworkException(): ...
///   }
/// }
/// ```
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = _toAppException(err);
    handler.next(err.copyWith(error: appException));
  }

  AppException _toAppException(DioException err) {
    // Explicit cancellation — not an error, caller should ignore.
    if (err.type == DioExceptionType.cancel) {
      return const AppException.cancelled();
    }

    // Connection-level errors (no response received).
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return AppException.network(message: err.message);
    }

    final statusCode = err.response?.statusCode;

    if (statusCode == null) {
      return AppException.unknown(message: err.message);
    }

    if (statusCode == 401) {
      return AppException.unauthorized(
        message: _extractMessage(err.response),
      );
    }

    if (statusCode == 422) {
      return AppException.validation(
        message: _extractMessage(err.response),
        fields: _extractFields(err.response),
      );
    }

    if (statusCode >= 400) {
      return AppException.serverError(
        statusCode: statusCode,
        message: _extractMessage(err.response),
      );
    }

    return AppException.unknown(message: err.message);
  }

  String? _extractMessage(Response<dynamic>? response) {
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      return data['message'] as String?;
    }
    return null;
  }

  /// Parses RFC 7807 `details` array into a map of field → [list of messages].
  ///
  /// A single field may have multiple validation failures, so the value type
  /// is `List<String>` rather than a single `String`.
  Map<String, List<String>>? _extractFields(Response<dynamic>? response) {
    final data = response?.data;
    if (data is! Map<String, dynamic>) return null;

    final details = data['details'];
    if (details is! List) return null;

    final fields = <String, List<String>>{};
    for (final item in details) {
      if (item is Map<String, dynamic>) {
        final field = item['field'] as String?;
        final message = item['message'] as String?;
        if (field != null && message != null) {
          fields.putIfAbsent(field, () => []).add(message);
        }
      }
    }
    return fields.isEmpty ? null : fields;
  }
}
