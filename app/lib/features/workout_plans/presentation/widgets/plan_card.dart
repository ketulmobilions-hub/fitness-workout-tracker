import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.onTap,
  });

  final WorkoutPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayCount = plan.days.length;
    final dayLabel = dayCount == 1 ? '1 day' : '$dayCount days';
    final scheduleLabel =
        plan.scheduleType == ScheduleType.weekly ? 'Weekly' : 'Recurring';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        plan.name,
        style: theme.textTheme.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: plan.description != null
          ? Text(
              plan.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _ScheduleChip(label: scheduleLabel),
          const SizedBox(height: 4),
          Text(dayLabel, style: theme.textTheme.bodySmall),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primaryContainer;
    final textColor = Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: textColor),
      ),
    );
  }
}
