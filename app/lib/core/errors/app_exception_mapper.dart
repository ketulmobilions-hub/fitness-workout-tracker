import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DriftWrappedException;
import 'package:sqlite3/common.dart' show SqliteException;

import 'app_exception.dart';

/// Normalises any thrown [Object] into a typed [AppException].
///
/// This is the single funnel that keeps raw, technical errors (Dio failures,
/// SQLite constraint violations, etc.) from ever reaching the UI. Business
/// logic (notifiers) should route caught errors through this before storing
/// them in state.
///
/// Mapping rules:
/// - Already an [AppException] → returned unchanged.
/// - [DioException] → the [AppException] the network [ErrorInterceptor] stashed
///   in `.error`, else [UnknownException].
/// - [SqliteException] / [DriftWrappedException] → [DatabaseException]. The raw
///   SQL / constraint text is intentionally dropped; only a generic flag is
///   kept so the UI can show a friendly message.
/// - Anything else → [UnknownException].
AppException mapToAppException(Object error) {
  if (error is AppException) return error;

  if (error is DioException) {
    final mapped = error.error;
    return mapped is AppException ? mapped : const AppException.unknown();
  }

  if (error is SqliteException || error is DriftWrappedException) {
    return const AppException.database();
  }

  return const AppException.unknown();
}

/// Short, user-facing message for an [AppException]. Single source of truth so
/// every banner/snackbar renders the same wording for the same failure.
extension AppExceptionMessage on AppException {
  String get userMessage => switch (this) {
        NetworkException() =>
          'No internet connection. Check your network and try again.',
        UnauthorizedException(:final message) =>
          message ?? 'Your session has expired. Please log in again.',
        ValidationException() => 'Please fix the errors and try again.',
        ServerException(:final statusCode) when statusCode == 409 =>
          'That already exists.',
        ServerException(:final message) =>
          message ?? 'Something went wrong on our end. Please try again.',
        DatabaseException() =>
          "Couldn't save your changes on this device. Please try again.",
        CancelledException() => '',
        UnknownException(:final message) =>
          message ?? 'Something went wrong. Please try again.',
      };
}
