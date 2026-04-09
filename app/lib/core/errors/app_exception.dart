import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_exception.freezed.dart';

@freezed
sealed class AppException with _$AppException implements Exception {
  /// No network connectivity or connection timed out.
  const factory AppException.network({String? message}) = NetworkException;

  /// Server returned 401 — token missing, expired, or invalid.
  const factory AppException.unauthorized({String? message}) =
      UnauthorizedException;

  /// Server returned 4xx/5xx (excluding 401 and 422).
  const factory AppException.serverError({
    required int statusCode,
    String? message,
  }) = ServerException;

  /// Server returned 422 — request body failed validation.
  ///
  /// [fields] maps each field name to its list of error messages.
  /// A single field can have multiple failures (e.g. "required" + "too short").
  const factory AppException.validation({
    String? message,
    Map<String, List<String>>? fields,
  }) = ValidationException;

  /// Request was cancelled by the caller (e.g. user navigated away).
  /// Not an error — callers should silently ignore this.
  const factory AppException.cancelled() = CancelledException;

  /// Catch-all for unexpected errors.
  const factory AppException.unknown({String? message}) = UnknownException;
}
