import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/sync/widgets/sync_status_indicator.dart';
import '../../providers/auth_notifier.dart';
import '../../providers/auth_state.dart';

/// Placeholder home screen. Will be replaced when Phase 1 workout features
/// are implemented (issues #13+).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    final greeting = switch (authState) {
      Authenticated(:final user) =>
        'Welcome, ${user.displayName ?? user.email ?? 'there'}!',
      AuthGuest() => 'Welcome, Guest!',
      _ => 'Welcome!',
    };

    final isGuest = authState is AuthGuest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Tracker'),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: SyncStatusIndicator(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fitness_center, size: 72),
              const SizedBox(height: 16),
              Text(
                greeting,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (isGuest) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'You are using a guest account. Create an account to save your progress.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.fitness_center),
                label: const Text('Browse Exercises'),
                onPressed: () => context.push(AppRoutes.exercises),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('My Plans'),
                onPressed: () => context.push(AppRoutes.plans),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Workout History'),
                onPressed: () => context.push(AppRoutes.workoutHistory),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
