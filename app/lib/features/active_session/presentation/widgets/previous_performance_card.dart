import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

/// Displays the set logs from the user's last session for the current exercise.
/// Shown as a compact reference card so the user knows what weight/reps to aim for.
class PreviousPerformanceCard extends StatelessWidget {
  const PreviousPerformanceCard({
    super.key,
    required this.previousSets,
  });

  final List<SetLog> previousSets;

  @override
  Widget build(BuildContext context) {
    if (previousSets.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Previous performance',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: previousSets.map((set) => _SetChip(set: set)).toList(),
          ),
        ],
      ),
    );
  }
}

class _SetChip extends StatelessWidget {
  const _SetChip({required this.set});

  final SetLog set;

  String _label() {
    final parts = <String>[];
    if (set.weightKg != null) {
      final w = set.weightKg!;
      parts.add(w == w.truncateToDouble() ? '${w.toInt()} kg' : '$w kg');
    }
    if (set.reps != null) parts.add('× ${set.reps}');
    if (parts.isEmpty && set.durationSec != null) {
      parts.add('${set.durationSec}s');
    }
    return parts.isEmpty ? 'Set ${set.setNumber}' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${set.setNumber}. ${_label()}',
        style: theme.textTheme.labelSmall,
      ),
    );
  }
}
