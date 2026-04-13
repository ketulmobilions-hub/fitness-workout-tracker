import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';

/// Displays a dismissible error banner for non-field auth errors.
/// Pass [error] from form state; returns [SizedBox.shrink] when null.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.error});

  final AppException? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();

    final message = switch (error!) {
      NetworkException() =>
        'No internet connection. Check your network and try again.',
      UnauthorizedException(:final message) =>
        message ?? 'Invalid credentials. Please check and try again.',
      ServerException(:final statusCode) when statusCode == 409 =>
        'An account with this email already exists.',
      ServerException(:final message) =>
        message ?? 'Something went wrong on our end. Please try again.',
      ValidationException() =>
        'Please fix the errors above and try again.',
      CancelledException() => null,
      UnknownException(:final message) =>
        message ?? 'Something went wrong. Please try again.',
    };

    if (message == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
