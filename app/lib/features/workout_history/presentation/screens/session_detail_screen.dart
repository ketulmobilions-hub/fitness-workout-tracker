import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/workout_history_providers.dart';
import '../widgets/session_exercise_tile.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(sessionExerciseLogsProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Detail'),
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to load workout detail.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Issue #16 fix: getSessionExerciseLogs reads from the local
                // DB (not the network), so a connectivity hint is misleading.
                Text(
                  'Something went wrong. Please try again.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: () =>
                      ref.invalidate(sessionExerciseLogsProvider(sessionId)),
                ),
              ],
            ),
          ),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fitness_center, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'No exercises logged for this session.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: logs.length,
            itemBuilder: (context, index) =>
                SessionExerciseTile(exerciseLog: logs[index]),
          );
        },
      ),
    );
  }
}
