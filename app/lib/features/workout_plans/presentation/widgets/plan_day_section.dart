import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

import 'plan_exercise_item.dart';

class PlanDaySection extends StatelessWidget {
  const PlanDaySection({super.key, required this.day});

  final PlanDay day;

  static const _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayName = day.name?.isNotEmpty == true
        ? day.name!
        : _dayNames[day.dayOfWeek % 7];
    final exerciseCount = day.exercises.length;
    final exerciseLabel =
        exerciseCount == 1 ? '1 exercise' : '$exerciseCount exercises';

    // Show "Week N" prefix only for recurring plans where weekNumber is set and
    // meaningful (non-zero). Weekly single-week plans omit the week prefix.
    final weekNumber = day.weekNumber;
    final title =
        weekNumber != null && weekNumber > 0 ? 'Week $weekNumber — $dayName' : dayName;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        exerciseLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      // Start collapsed so Flutter can lazily render exercise items — avoids
      // building all widgets at once on a 7-day / 50-exercise plan.
      initiallyExpanded: false,
      children: day.exercises.isEmpty
          ? [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'No exercises added yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ]
          : day.exercises
              .map((ex) => PlanExerciseItem(exercise: ex))
              .toList(),
    );
  }
}
