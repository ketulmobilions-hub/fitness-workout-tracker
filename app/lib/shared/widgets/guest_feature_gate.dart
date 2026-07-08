import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';

/// Shows a modal bottom sheet telling a guest that the action they tapped
/// needs a full account, with a Create Account CTA. Use this to gate a single
/// action (a FAB, a list tile) — for a whole screen use [GuestFeatureGate].
Future<void> showGuestUpgradePrompt(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      final text = Theme.of(sheetContext).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_outline, size: 40, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  // go (not push): registering replaces the stack; GoRouter's
                  // redirect sends the new full account to /home.
                  context.go(AppRoutes.register);
                },
                child: const Text('Create Account'),
              ),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Full-screen empty state shown to guest accounts on features that require a
/// full account (the server gates these behind `requireFullAccount` and returns
/// 403). Rendering this instead of the real screen means the gated data
/// providers are never watched, so no forbidden API calls are made.
class GuestFeatureGate extends StatelessWidget {
  const GuestFeatureGate({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.lock_outline,
  });

  /// Short headline, e.g. "Progress is a member feature".
  final String title;

  /// One or two lines explaining what signing up unlocks.
  final String message;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(
              // context.go (not push) so registering replaces this stack;
              // GoRouter's redirect sends the new full account to /home.
              onPressed: () => context.go(AppRoutes.register),
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
