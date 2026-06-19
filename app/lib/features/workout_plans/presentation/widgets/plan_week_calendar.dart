import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:ironlog/features/workout_plans/presentation/widgets/plan_exercise_item.dart';

// 0-based JS convention: 0=Sun, 1=Mon, …, 6=Sat — matches server schema
// (plan.routes.ts: dayOfWeek z.number().int().min(0).max(6)).
const _kDayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

String _dayName(PlanDay day) {
  final name = day.name;
  if (name != null && name.isNotEmpty) return name;
  return _kDayNames[day.dayOfWeek % 7];
}

/// Multi-week calendar view for recurring plans with more than one week.
///
/// Shows a sticky week-selector chip row at the top and an animated,
/// expandable day card list below it. Must be placed inside a widget that
/// provides a bounded vertical constraint (e.g. [Expanded]).
class PlanWeekCalendar extends StatefulWidget {
  const PlanWeekCalendar({
    super.key,
    required this.plan,
    required this.selectedWeek,
    required this.onWeekSelected,
    required this.onStartDay,
  });

  final WorkoutPlan plan;
  final int selectedWeek;
  final ValueChanged<int> onWeekSelected;

  /// Called when the user taps the start button on a specific day card.
  final ValueChanged<PlanDay> onStartDay;

  @override
  State<PlanWeekCalendar> createState() => _PlanWeekCalendarState();
}

class _PlanWeekCalendarState extends State<PlanWeekCalendar> {
  final ScrollController _weekScrollCtrl = ScrollController();

  // Non-final: rebuilt in didUpdateWidget when plan data changes.
  Map<int, List<PlanDay>> _daysByWeek = {};
  List<int> _weekNumbers = [];
  Set<int> _deloadWeeks = {};

  // Expansion state keyed by day ID — survives week switches and stream ticks.
  final Set<String> _expandedDayIds = {};

  @override
  void initState() {
    super.initState();
    _buildWeekMap();
  }

  @override
  void didUpdateWidget(PlanWeekCalendar old) {
    super.didUpdateWidget(old);
    // setState ensures the widget rebuilds with the new _daysByWeek/_weekNumbers.
    if (old.plan != widget.plan) setState(_buildWeekMap);
  }

  void _buildWeekMap() {
    final map = <int, List<PlanDay>>{};
    for (final day in widget.plan.days) {
      final wk = day.weekNumber;
      if (wk == null) {
        // Malformed recurring day — weekNumber should always be set.
        assert(false, 'PlanDay "${day.id}" has null weekNumber on a recurring plan');
        debugPrint('[PlanWeekCalendar] Day ${day.id} missing weekNumber; placed in week 1');
      }
      (map[wk ?? 1] ??= []).add(day);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    _daysByWeek = map;
    _weekNumbers = map.keys.toList()..sort();
    // A week is a deload week if any day in it has isDeload = true.
    _deloadWeeks = {
      for (final entry in map.entries)
        if (entry.value.any((d) => d.isDeload)) entry.key,
    };
    // If the parent's selected week is no longer in the updated week list
    // (e.g. plan was reloaded after a server edit), nudge the parent to select
    // the first valid week. Must happen post-frame — can't call setState from
    // within setState (didUpdateWidget) or from initState.
    if (_weekNumbers.isNotEmpty && !_weekNumbers.contains(widget.selectedWeek)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onWeekSelected(_weekNumbers.first);
      });
    }
  }

  void _toggleDay(String dayId) {
    setState(() {
      if (_expandedDayIds.contains(dayId)) {
        _expandedDayIds.remove(dayId);
      } else {
        _expandedDayIds.add(dayId);
      }
    });
  }

  @override
  void dispose() {
    _weekScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysByWeek[widget.selectedWeek] ?? [];

    return Column(
      children: [
        // Sticky week selector — lives outside the scroll view so it never scrolls away.
        _WeekSelectorBar(
          weekNumbers: _weekNumbers,
          selectedWeek: widget.selectedWeek,
          deloadWeeks: _deloadWeeks,
          onSelected: widget.onWeekSelected,
          scrollController: _weekScrollCtrl,
        ),
        if (_deloadWeeks.contains(widget.selectedWeek)) const _DeloadBanner(),
        const Divider(height: 1),
        Expanded(
          child: days.isEmpty
              ? Center(
                  child: Text(
                    'No days configured for week ${widget.selectedWeek}.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: days.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    return _WeekDayCard(
                      key: ValueKey(day.id),
                      day: day,
                      isExpanded: _expandedDayIds.contains(day.id),
                      onToggle: () => _toggleDay(day.id),
                      onStartDay: widget.onStartDay,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Week selector bar
// ---------------------------------------------------------------------------

class _WeekSelectorBar extends StatelessWidget {
  const _WeekSelectorBar({
    required this.weekNumbers,
    required this.selectedWeek,
    required this.deloadWeeks,
    required this.onSelected,
    required this.scrollController,
  });

  final List<int> weekNumbers;
  final int selectedWeek;
  final Set<int> deloadWeeks;
  final ValueChanged<int> onSelected;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'SELECT WEEK',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: weekNumbers.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final wk = weekNumbers[index];
                final isSelected = wk == selectedWeek;
                final isDeloadWk = deloadWeeks.contains(wk);
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Wk $wk'),
                      if (isDeloadWk) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_downward, size: 12),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (_) => onSelected(wk),
                  showCheckmark: false,
                  tooltip: isDeloadWk ? 'Deload week' : null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Deload week banner
// ---------------------------------------------------------------------------

class _DeloadBanner extends StatelessWidget {
  const _DeloadBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      color: cs.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.arrow_downward, size: 16, color: cs.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Deload week — reduce weights to 60–70% of normal. Focus on recovery.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day card — stateless; expansion state owned by PlanWeekCalendarState
// ---------------------------------------------------------------------------

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    super.key,
    required this.day,
    required this.isExpanded,
    required this.onToggle,
    required this.onStartDay,
  });

  final PlanDay day;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<PlanDay> onStartDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises = day.exercises;
    final exCount = exercises.length;
    final exLabel = exCount == 1 ? '1 exercise' : '$exCount exercises';
    final hasExercises = exercises.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_dayName(day), style: theme.textTheme.titleSmall),
                            if (day.isDeload) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'DELOAD',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onTertiaryContainer,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          exLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline),
                    tooltip: hasExercises
                        ? 'Start this day'
                        : 'No exercises — add some first',
                    color: hasExercises
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    onPressed: hasExercises ? () => onStartDay(day) : null,
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // AnimatedSize gives a smooth expand/collapse transition.
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1, indent: 16),
                      if (!hasExercises)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Text(
                            'No exercises added yet.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ...exercises.map((ex) => PlanExerciseItem(exercise: ex)),
                      const SizedBox(height: 4),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
