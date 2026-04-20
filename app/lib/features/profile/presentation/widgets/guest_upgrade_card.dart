import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';

class GuestUpgradeCard extends StatelessWidget {
  const GuestUpgradeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_circle_outlined,
                    color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Save your progress',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You are using a guest account. Create a free account to save your workouts, streaks, and progress.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              // Issue #19: use context.go instead of context.push so the
              // register screen replaces the profile/settings stack. After
              // successful registration GoRouter's redirect takes the user to
              // /home. Using push would leave the (guest) profile screen
              // underneath, making back-navigation return to guest state.
              onPressed: () => context.go(AppRoutes.register),
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
