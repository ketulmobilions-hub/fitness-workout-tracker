import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
  });

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        exercise.name,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: exercise.description != null
          ? Text(
              exercise.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      // Constrain trailing to avoid overflow when the type label is wide.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExerciseTypeChip(type: exercise.exerciseType),
            if (exercise.isCustom) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.person,
                size: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ExerciseTypeChip extends StatelessWidget {
  const _ExerciseTypeChip({required this.type});

  final ExerciseType type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      ExerciseType.strength => (
          'Strength',
          Theme.of(context).colorScheme.primaryContainer,
        ),
      ExerciseType.cardio => (
          'Cardio',
          Theme.of(context).colorScheme.tertiaryContainer,
        ),
      ExerciseType.stretching => (
          'Stretch',
          Theme.of(context).colorScheme.secondaryContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
