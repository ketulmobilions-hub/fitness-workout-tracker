import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

/// Shared icon widget for displaying an exercise type with its associated
/// colour. Used in both the plan form's draggable item and the exercise picker.
class ExerciseTypeIcon extends StatelessWidget {
  const ExerciseTypeIcon({super.key, required this.type, this.size = 22});

  final ExerciseType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (type) {
      ExerciseType.strength => (Icons.fitness_center, colorScheme.primary),
      ExerciseType.cardio => (Icons.directions_run, colorScheme.tertiary),
      ExerciseType.stretching => (
          Icons.self_improvement,
          colorScheme.secondary,
        ),
    };
    return Icon(icon, size: size, color: color);
  }
}
