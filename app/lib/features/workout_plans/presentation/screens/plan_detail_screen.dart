import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../providers/plan_detail_provider.dart';
import '../widgets/plan_day_section.dart';

class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planDetailProvider(planId));

    return Scaffold(
      appBar: AppBar(
        title: planAsync.maybeWhen(
          data: (plan) => Text(plan?.name ?? 'Plan'),
          orElse: () => const Text('Plan'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit plan',
            onPressed: () => context.push(AppRoutes.editPlanPath(planId)),
          ),
        ],
      ),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not load plan.\nCheck your connection and try again.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: () =>
                      ref.read(planDetailProvider(planId).notifier).refresh(),
                ),
              ],
            ),
          ),
        ),
        data: (plan) {
          if (plan == null) {
            return const Center(child: Text('Plan not found.'));
          }
          return _PlanDetailBody(plan: plan);
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Workout'),
            // Workout logging is a future issue — disabled for now.
            onPressed: null,
          ),
        ),
      ),
    );
  }
}

class _PlanDetailBody extends StatelessWidget {
  const _PlanDetailBody({required this.plan});

  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Schedule type + active badge
                Wrap(
                  spacing: 8,
                  children: [
                    _MetadataChip(
                      label: plan.scheduleType == ScheduleType.weekly
                          ? 'Weekly'
                          : 'Recurring',
                      icon: Icons.calendar_today_outlined,
                    ),
                    if (plan.scheduleType == ScheduleType.recurring &&
                        plan.weeksCount != null)
                      _MetadataChip(
                        label: '${plan.weeksCount} weeks',
                        icon: Icons.repeat,
                      ),
                    if (plan.isActive)
                      _MetadataChip(
                        label: 'Active',
                        icon: Icons.check_circle_outline,
                        color: theme.colorScheme.secondaryContainer,
                        textColor: theme.colorScheme.onSecondaryContainer,
                      ),
                  ],
                ),
                // Use a local variable — avoids a stale force-unwrap if this
                // block is ever refactored or extracted to a helper.
                Builder(builder: (context) {
                  final description = plan.description;
                  if (description == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(description, style: theme.textTheme.bodyMedium),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                const Divider(height: 1),
              ],
            ),
          ),
        ),
        if (plan.days.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No workout days configured yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final day = plan.days[index];
                return Column(
                  children: [
                    PlanDaySection(day: day),
                    if (index < plan.days.length - 1)
                      const Divider(height: 1, indent: 16),
                  ],
                );
              },
              childCount: plan.days.length,
            ),
          ),
      ],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({
    required this.label,
    required this.icon,
    this.color,
    this.textColor,
  });

  final String label;
  final IconData icon;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = color ?? theme.colorScheme.surfaceContainerHighest;
    final fgColor = textColor ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: fgColor),
          ),
        ],
      ),
    );
  }
}
