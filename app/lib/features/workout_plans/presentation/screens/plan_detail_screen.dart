import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../active_session/providers/active_session_notifier.dart';
import '../../providers/plan_detail_provider.dart';
import '../widgets/plan_day_section.dart';

class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  bool _isStartingSession = false;

  Future<void> _onStartWorkout(WorkoutPlan plan) async {
    if (_isStartingSession) return;

    PlanDay? selectedDay;

    if (plan.days.isEmpty) {
      // Free workout — no plan day selected.
      selectedDay = null;
    } else if (plan.days.length == 1) {
      selectedDay = plan.days.first;
    } else {
      // Let the user pick which day to do.
      selectedDay = await showModalBottomSheet<PlanDay>(
        context: context,
        builder: (ctx) => _DayPickerSheet(days: plan.days),
      );
      if (selectedDay == null || !mounted) return;
    }

    setState(() => _isStartingSession = true);
    try {
      await ref.read(activeSessionProvider.notifier).startSession(
            planId: plan.id,
            planDayId: selectedDay?.id,
            exercises: selectedDay?.exercises ?? [],
          );
      if (!mounted) return;
      context.push(AppRoutes.activeWorkout);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start workout: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isStartingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(planDetailProvider(widget.planId));

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
            onPressed: () =>
                context.push(AppRoutes.editPlanPath(widget.planId)),
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
                  onPressed: () => ref
                      .read(planDetailProvider(widget.planId).notifier)
                      .refresh(),
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
          child: planAsync.maybeWhen(
            data: (plan) => FilledButton.icon(
              icon: _isStartingSession
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('Start Workout'),
              onPressed: _isStartingSession || plan == null
                  ? null
                  : () => _onStartWorkout(plan),
            ),
            orElse: () => FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Workout'),
              onPressed: null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for selecting which plan day to start.
class _DayPickerSheet extends StatelessWidget {
  const _DayPickerSheet({required this.days});

  final List<PlanDay> days;

  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _dayLabel(PlanDay day) {
    if (day.name != null && day.name!.isNotEmpty) return day.name!;
    if (day.dayOfWeek >= 1 && day.dayOfWeek <= 7) {
      return _dayNames[day.dayOfWeek - 1];
    }
    return 'Day ${day.sortOrder + 1}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Select workout day',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...days.map(
            (day) => ListTile(
              title: Text(_dayLabel(day)),
              subtitle: day.exercises.isNotEmpty
                  ? Text(
                      '${day.exercises.length} exercise${day.exercises.length == 1 ? '' : 's'}')
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(day),
            ),
          ),
          const SizedBox(height: 8),
        ],
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
