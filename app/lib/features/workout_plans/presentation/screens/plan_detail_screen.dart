import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../active_session/providers/active_session_notifier.dart';
import '../../providers/plan_detail_provider.dart';
import '../widgets/plan_day_section.dart';
import '../widgets/plan_week_calendar.dart';

// 0-based JS convention: 0=Sun, 1=Mon, …, 6=Sat — must match plan_week_calendar.dart
// and server schema (plan.routes.ts: dayOfWeek z.number().int().min(0).max(6)).
const _kDayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  bool _isStartingSession = false;

  // Initialized from the plan's actual minimum week number on first data load.
  int _selectedWeek = 1;
  bool _weekInitialized = false;

  bool _isMultiWeek(WorkoutPlan plan) =>
      plan.scheduleType == ScheduleType.recurring &&
      (plan.weeksCount ?? 0) > 1;

  Future<void> _onStartWorkout(WorkoutPlan plan, {PlanDay? preselectedDay}) async {
    if (_isStartingSession) return;

    PlanDay? selectedDay;

    if (preselectedDay != null) {
      selectedDay = preselectedDay;
    } else if (plan.days.isEmpty) {
      selectedDay = null;
    } else {
      final candidates = _isMultiWeek(plan)
          ? plan.days
              .where((d) => (d.weekNumber ?? 1) == _selectedWeek)
              .toList()
          : plan.days;

      if (candidates.isEmpty) {
        selectedDay = null;
      } else if (candidates.length == 1) {
        selectedDay = candidates.first;
      } else {
        selectedDay = await showModalBottomSheet<PlanDay>(
          context: context,
          builder: (ctx) => _DayPickerSheet(days: candidates),
        );
        if (selectedDay == null || !mounted) return;
      }
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

    // Initialize _selectedWeek from the plan's actual minimum week number.
    // Also clamp on subsequent data changes (e.g., Drift stream re-emission)
    // in case the plan structure changed while the screen was open.
    ref.listen(planDetailProvider(widget.planId), (_, next) {
      next.whenData((plan) {
        if (plan == null || !_isMultiWeek(plan)) return;
        final weekNumbers = plan.days
            .map((d) => d.weekNumber ?? 1)
            .toSet()
            .toList()
          ..sort();
        if (weekNumbers.isEmpty) return;
        if (!_weekInitialized) {
          setState(() {
            _selectedWeek = weekNumbers.first;
            _weekInitialized = true;
          });
        } else if (!weekNumbers.contains(_selectedWeek)) {
          // Current selection no longer valid — clamp to nearest.
          setState(() {
            _selectedWeek = weekNumbers.reduce(
              (a, b) => (a - _selectedWeek).abs() <= (b - _selectedWeek).abs()
                  ? a
                  : b,
            );
          });
        }
      });
    });

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
                  onPressed: () =>
                      ref.invalidate(planDetailProvider(widget.planId)),
                ),
              ],
            ),
          ),
        ),
        data: (plan) {
          if (plan == null) {
            return const Center(child: Text('Plan not found.'));
          }
          if (_isMultiWeek(plan)) {
            return _MultiWeekBody(
              plan: plan,
              selectedWeek: _selectedWeek,
              onWeekSelected: (wk) => setState(() => _selectedWeek = wk),
              onStartDay: (day) => _onStartWorkout(plan, preselectedDay: day),
            );
          }
          return _PlanDetailBody(plan: plan);
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: planAsync.maybeWhen(
            data: (plan) {
              if (plan == null) {
                return FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Workout'),
                  onPressed: null,
                );
              }

              final isMultiWeek = _isMultiWeek(plan);
              final weekHasDays = !isMultiWeek ||
                  plan.days.any((d) => (d.weekNumber ?? 1) == _selectedWeek);

              final label = isMultiWeek
                  ? weekHasDays
                      ? 'Start Week $_selectedWeek Workout'
                      : 'No days in week $_selectedWeek'
                  : 'Start Workout';

              return FilledButton.icon(
                icon: _isStartingSession
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(label),
                onPressed: _isStartingSession || !weekHasDays
                    ? null
                    : () => _onStartWorkout(plan),
              );
            },
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

// ---------------------------------------------------------------------------
// Multi-week body — wraps PlanWeekCalendar with the plan header.
// PlanWeekCalendar requires a bounded vertical constraint — this widget
// provides one by nesting it inside an Expanded within its own Column.
// ---------------------------------------------------------------------------

class _MultiWeekBody extends StatelessWidget {
  const _MultiWeekBody({
    required this.plan,
    required this.selectedWeek,
    required this.onWeekSelected,
    required this.onStartDay,
  });

  final WorkoutPlan plan;
  final int selectedWeek;
  final ValueChanged<int> onWeekSelected;
  final ValueChanged<PlanDay> onStartDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlanHeader(plan: plan),
        const Divider(height: 1),
        Expanded(
          child: PlanWeekCalendar(
            plan: plan,
            selectedWeek: selectedWeek,
            onWeekSelected: onWeekSelected,
            onStartDay: onStartDay,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Single-week / weekly body
// ---------------------------------------------------------------------------

class _PlanDetailBody extends StatelessWidget {
  const _PlanDetailBody({required this.plan});

  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _PlanHeader(plan: plan),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
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

// ---------------------------------------------------------------------------
// Plan header — metadata chips + description (shared by both views)
// ---------------------------------------------------------------------------

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan});

  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
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
          Builder(builder: (context) {
            final description = plan.description;
            if (description == null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(description, style: theme.textTheme.bodyMedium),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day picker sheet (used when multiple days exist in a week)
// ---------------------------------------------------------------------------

class _DayPickerSheet extends StatelessWidget {
  const _DayPickerSheet({required this.days});

  final List<PlanDay> days;

  String _dayLabel(PlanDay day) {
    if (day.name != null && day.name!.isNotEmpty) return day.name!;
    // 0-based index: 0=Sun, 1=Mon, …, 6=Sat (JS convention, per server schema)
    if (day.dayOfWeek >= 0 && day.dayOfWeek <= 6) {
      return _kDayNames[day.dayOfWeek];
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

// ---------------------------------------------------------------------------
// Metadata chip
// ---------------------------------------------------------------------------

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
