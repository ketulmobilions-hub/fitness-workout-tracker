import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

class MuscleGroupChip extends StatelessWidget {
  const MuscleGroupChip({
    super.key,
    required this.muscleGroup,
  });

  final MuscleGroup muscleGroup;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(muscleGroup.displayName),
      avatar: muscleGroup.isPrimary
          ? Icon(
              Icons.star,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      labelStyle: Theme.of(context).textTheme.labelSmall,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
