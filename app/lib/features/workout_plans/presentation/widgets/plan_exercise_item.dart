import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

class PlanExerciseItem extends StatelessWidget {
  const PlanExerciseItem({super.key, required this.exercise});

  final PlanDayExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Compute once to avoid double-calling the helper on every build.
    final summary = _targetSummary(exercise);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _ExerciseTypeIcon(type: exercise.exerciseType),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exerciseName,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (summary.isNotEmpty)
                  Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _targetSummary(PlanDayExercise ex) {
    if (ex.targetSets != null && ex.targetReps != null) {
      return '${ex.targetSets} × ${ex.targetReps}';
    }
    if (ex.targetSets != null) {
      return '${ex.targetSets} sets';
    }
    if (ex.targetDurationSec != null) {
      final mins = ex.targetDurationSec! ~/ 60;
      final secs = ex.targetDurationSec! % 60;
      if (mins > 0 && secs > 0) return '${mins}m ${secs}s';
      if (mins > 0) return '$mins min';
      return '${secs}s';
    }
    if (ex.targetDistanceM != null) {
      return '${(ex.targetDistanceM! / 1000).toStringAsFixed(1)} km';
    }
    return '';
  }
}

class _ExerciseTypeIcon extends StatelessWidget {
  const _ExerciseTypeIcon({required this.type});

  final ExerciseType type;

  @override
  Widget build(BuildContext context) {
    // Use theme-aware colors so icons meet WCAG AA contrast in both light and
    // dark modes instead of hardcoded Color constants.
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (type) {
      ExerciseType.strength => (Icons.fitness_center, colorScheme.primary),
      ExerciseType.cardio => (Icons.directions_run, colorScheme.tertiary),
      ExerciseType.stretching => (
          Icons.self_improvement,
          colorScheme.secondary
        ),
    };
    return Icon(icon, size: 20, color: color);
  }
}
