import 'package:dio/dio.dart';

/// Intercepts 401 Unauthorized responses and automatically retries the
/// original request after refreshing the JWT access token.
///
/// ## How it works
/// 1. A request returns 401 (token expired).
/// 2. This interceptor calls [onRefresh] to exchange the refresh token for
///    new tokens (via the `/auth/refresh` endpoint on an **inner** Dio that
///    does not carry this interceptor, preventing recursion).
/// 3. On success: the original request is retried with the new access token.
///    If the retry itself receives an error status, it is propagated as an
///    exception rather than resolved — prevents callers silently receiving
///    error responses (e.g. a revoked token returning 401 on first use).
/// 4. If multiple requests 401 at the same time, only one refresh is issued;
///    the rest are queued and replayed after the single refresh completes.
/// 5. On refresh failure: [onRefreshFailed] is called (clears tokens),
///    and all queued requests receive a DioException carrying their original
///    401 response metadata. GoRouter then redirects to the login screen.
///
/// **Do not add this interceptor to the inner [innerDio]** — that is the Dio
/// instance used for the refresh call itself. Doing so would cause infinite
/// recursion on a bad refresh token.
class RefreshInterceptor extends Interceptor {
  RefreshInterceptor({
    required Dio innerDio,
    required Future<void> Function() onRefresh,
    required Future<void> Function() onRefreshFailed,
    required Future<String?> Function() newAccessTokenReader,
  })  : _innerDio = innerDio,
        _onRefresh = onRefresh,
        _onRefreshFailed = onRefreshFailed,
        _newAccessTokenReader = newAccessTokenReader;

  final Dio _innerDio;
  final Future<void> Function() _onRefresh;
  final Future<void> Function() _onRefreshFailed;
  final Future<String?> Function() _newAccessTokenReader;

  bool _isRefreshing = false;
  final List<_QueuedRequest> _queue = [];

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only handle 401 responses.
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Skip the refresh endpoint itself to avoid infinite recursion.
    if (err.requestOptions.path.contains('/auth/refresh')) {
      handler.next(err);
      return;
    }

    // Skip requests that have already been retried once to prevent loops.
    // Do not call _onRefreshFailed() here — if we reached this path via the
    // normal retry flow, _onRefreshFailed() was already called in the catch
    // block below. Calling it again would double-clear tokens and could emit
    // a second AuthState.unauthenticated transition, causing duplicate
    // router redirects.
    if (err.requestOptions.extra['_retried'] == true) {
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      // Queue this request — it will be replayed once the in-flight refresh
      // completes. The original 401 response is stored so it can be surfaced
      // in the failure DioException if the refresh ultimately fails.
      _queue.add(_QueuedRequest(
        options: err.requestOptions,
        handler: handler,
        originalResponse: err.response,
      ));
      return;
    }

    _isRefreshing = true;
    try {
      await _onRefresh();
      final newToken = await _newAccessTokenReader();

      // Retry the original request with the fresh token.
      // Copy options so we don't mutate the object while innerDio uses it.
      final retryOptions = _copyWithRetry(err.requestOptions, newToken);
      final response = await _innerDio.fetch<dynamic>(retryOptions);
      _resolveOrReject(handler, retryOptions, response);

      // Replay all queued requests with their own defensive copies.
      for (final queued in _queue) {
        try {
          final qOptions = _copyWithRetry(queued.options, newToken);
          final qResponse = await _innerDio.fetch<dynamic>(qOptions);
          _resolveOrReject(queued.handler, qOptions, qResponse);
        } catch (e) {
          // Propagate the actual retry failure, not the original 401.
          queued.handler.next(
            e is DioException
                ? e
                : DioException(requestOptions: queued.options, error: e),
          );
        }
      }
    } catch (_) {
      // Refresh failed — sign the user out and reject all queued requests
      // with their original 401 response metadata so callers can distinguish
      // auth failures from network errors.
      await _onRefreshFailed();
      for (final queued in _queue) {
        queued.handler.next(
          DioException(
            requestOptions: queued.options,
            response: queued.originalResponse,
            type: DioExceptionType.badResponse,
            message: 'Token refresh failed',
          ),
        );
      }
      handler.next(err);
    } finally {
      _isRefreshing = false;
      _queue.clear();
    }
  }

  /// Resolves [handler] with [response] if the status is a success, or
  /// forwards a [DioException] if the server returned an error status.
  /// This prevents retried requests from being resolved as successes when
  /// the freshly issued token is immediately rejected (e.g. clock skew,
  /// revocation), which would bypass [ErrorInterceptor] downstream.
  void _resolveOrReject(
    ErrorInterceptorHandler handler,
    RequestOptions options,
    Response<dynamic> response,
  ) {
    if ((response.statusCode ?? 0) >= 400) {
      handler.next(DioException(
        requestOptions: options,
        response: response,
        type: DioExceptionType.badResponse,
      ));
    } else {
      handler.resolve(response);
    }
  }

  /// Returns a shallow copy of [options] with `_retried = true` and the
  /// updated Authorization header. Copying prevents mutating an object that
  /// may still be referenced elsewhere (e.g. while innerDio is executing it).
  RequestOptions _copyWithRetry(RequestOptions options, String? newToken) {
    return options.copyWith(
      headers: {
        ...options.headers,
        'Authorization': 'Bearer $newToken',
      },
      extra: {
        ...options.extra,
        '_retried': true,
      },
    );
  }
}

class _QueuedRequest {
  _QueuedRequest({
    required this.options,
    required this.handler,
    this.originalResponse,
  });

  final RequestOptions options;
  final ErrorInterceptorHandler handler;

  /// The original 401 response. Stored so it can be included in the
  /// DioException surfaced to callers when token refresh fails, allowing
  /// error handlers to inspect the status code and distinguish auth errors
  /// from network errors.
  final Response<dynamic>? originalResponse;
}
