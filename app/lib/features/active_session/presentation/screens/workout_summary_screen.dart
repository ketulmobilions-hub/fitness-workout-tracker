import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../providers/active_session_notifier.dart';

/// Displayed after a session is successfully completed.
/// Receives a [WorkoutSummary] via GoRouter [extra].
class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({super.key, required this.summary});

  final WorkoutSummary summary;

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds ~/ 60).remainder(60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercisesWithSets =
        summary.exerciseData.where((e) => e.loggedSets.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Complete'),
        automaticallyImplyLeading: false,
      ),
      body: CustomScrollView(
        slivers: [
          // ── Hero banner ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: theme.colorScheme.primaryContainer,
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Great work!',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Stats row ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: _formatDuration(summary.durationSec),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.fitness_center,
                      label: 'Exercises',
                      value: '${exercisesWithSets.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Sets',
                      value: '${summary.totalSets}',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── New PRs ──────────────────────────────────────────────────────
          if (summary.newPRs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'New Personal Records',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final pr = summary.newPRs[i];
                  final recordLabel = switch (pr.recordType) {
                    'max_weight' => '${pr.value} kg max weight',
                    'max_reps' => '${pr.value.toInt()} max reps',
                    'max_volume' => '${pr.value.toInt()} kg total volume',
                    'best_pace' =>
                      '${pr.value.toStringAsFixed(1)} s/km pace',
                    _ => '${pr.value} ${pr.recordType}',
                  };
                  return ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(pr.exerciseName),
                    subtitle: Text(recordLabel),
                  );
                },
                childCount: summary.newPRs.length,
              ),
            ),
            const SliverToBoxAdapter(
              child: Divider(indent: 16, endIndent: 16),
            ),
          ],

          // ── Exercise log summary ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Exercise Summary',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final exData = exercisesWithSets[i];
                final sets = exData.loggedSets;
                return ExpansionTile(
                  title: Text(exData.planExercise.exerciseName),
                  subtitle: Text(
                    '${sets.length} set${sets.length == 1 ? '' : 's'}',
                  ),
                  children: sets
                      .map((s) => ListTile(
                            dense: true,
                            leading: Text(
                              'Set ${s.setNumber}',
                              style: theme.textTheme.labelSmall,
                            ),
                            title: Text(_setLabel(s)),
                          ))
                      .toList(),
                );
              },
              childCount: exercisesWithSets.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Done'),
          ),
        ),
      ),
    );
  }

  String _setLabel(SetLog set) {
    final parts = <String>[];
    if (set.weightKg != null) {
      final w = set.weightKg!;
      parts.add(w == w.truncateToDouble() ? '${w.toInt()} kg' : '$w kg');
    }
    if (set.reps != null) parts.add('× ${set.reps}');
    if (set.rpe != null) parts.add('RPE ${set.rpe}');
    if (parts.isEmpty && set.durationSec != null) parts.add('${set.durationSec}s');
    return parts.isEmpty ? '—' : parts.join('  ');
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
