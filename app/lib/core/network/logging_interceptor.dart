import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Logs HTTP requests, responses, and errors to the debug console.
///
/// Only active when [kDebugMode] is true — compiled away in release builds.
/// Sensitive headers (Authorization) are redacted to prevent JWT leakage
/// in crash reporter breadcrumbs (e.g. Sentry).
class LoggingInterceptor extends Interceptor {
  static const _redactedHeaders = {'authorization', 'Authorization'};

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    return {
      for (final entry in headers.entries)
        entry.key: _redactedHeaders.contains(entry.key) ? '[REDACTED]' : entry.value,
    };
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '[HTTP →] ${options.method} ${options.uri}\n'
        '  headers: ${_sanitizeHeaders(options.headers)}\n'
        '  body: ${options.data}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '[HTTP ←] ${response.statusCode} ${response.requestOptions.uri}\n'
        '  body: ${response.data}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '[HTTP ✗] ${err.response?.statusCode} ${err.requestOptions.uri}\n'
        '  type: ${err.type}\n'
        '  message: ${err.message}\n'
        '  body: ${err.response?.data}',
      );
    }
    handler.next(err);
  }
}
