import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

/// Displays the set logs from the user's last session for the current exercise.
/// Shown as a compact reference card so the user knows what weight/reps to aim for.
class PreviousPerformanceCard extends StatelessWidget {
  const PreviousPerformanceCard({
    super.key,
    required this.previousSets,
    required this.exerciseType,
  });

  final List<SetLog> previousSets;
  // Fix #12: exercise type drives the chip format — avoids field-presence
  // heuristics that misclassify e.g. a timed plank (no weight/reps) as cardio.
  final ExerciseType exerciseType;

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
            children: previousSets
                .map((set) =>
                    _SetChip(set: set, exerciseType: exerciseType))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SetChip extends StatelessWidget {
  const _SetChip({required this.set, required this.exerciseType});

  final SetLog set;
  final ExerciseType exerciseType;

  String _label() {
    if (exerciseType != ExerciseType.strength) {
      // Cardio / stretching: distance · duration
      final parts = <String>[];
      if (set.distanceM != null) {
        final km = set.distanceM! / 1000;
        parts.add('${km.toStringAsFixed(2)} km');
      }
      if (set.durationSec != null) {
        final mins = set.durationSec! ~/ 60;
        final secs = set.durationSec! % 60;
        parts.add('$mins:${secs.toString().padLeft(2, '0')}');
      }
      return parts.isEmpty ? 'Set ${set.setNumber}' : parts.join(' · ');
    }

    // Strength: weight × reps
    final parts = <String>[];
    if (set.weightKg != null) {
      final w = set.weightKg!;
      parts.add(w == w.truncateToDouble() ? '${w.toInt()} kg' : '$w kg');
    }
    if (set.reps != null) parts.add('× ${set.reps}');
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
