import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/app_exception_mapper.dart';

/// Reusable, feature-agnostic error banner. Renders the friendly [userMessage]
/// for an [AppException]; collapses to nothing when [error] is null or maps to
/// an empty message (e.g. a cancelled request).
class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({super.key, required this.error});

  final AppException? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();

    final message = error!.userMessage;
    if (message.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
