import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../providers/workout_history_providers.dart';
import '../widgets/session_history_card.dart';

enum _ViewMode { list, calendar }

class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState
    extends ConsumerState<WorkoutHistoryScreen> {
  _ViewMode _viewMode = _ViewMode.list;
  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(completedSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
        actions: [
          IconButton(
            icon: Icon(
              _viewMode == _ViewMode.list
                  ? Icons.calendar_month
                  : Icons.view_list,
            ),
            tooltip: _viewMode == _ViewMode.list
                ? 'Switch to calendar view'
                : 'Switch to list view',
            onPressed: () => setState(
              () => _viewMode = _viewMode == _ViewMode.list
                  ? _ViewMode.calendar
                  : _ViewMode.list,
            ),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to load workout history.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  // Error recovery: invalidate to restart the Drift stream.
                  // This is different from pull-to-refresh which only syncs
                  // from the server without restarting the stream.
                  onPressed: () =>
                      ref.invalidate(completedSessionsProvider),
                ),
              ],
            ),
          ),
        ),
        data: (sessions) => _HistoryBody(
          sessions: sessions,
          viewMode: _viewMode,
          selectedDay: _selectedDay,
          focusedDay: _focusedDay,
          onDaySelected: (selected, focused) => setState(() {
            _selectedDay =
                isSameDay(_selectedDay, selected) ? null : selected;
            _focusedDay = focused;
          }),
          // Issue #2 fix: pull-to-refresh calls the notifier's refresh()
          // method instead of invalidating the provider. This syncs fresh
          // data from the server without tearing down the Drift subscription.
          onRefresh: () =>
              ref.read(completedSessionsProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

/// Issue #6 fix: StatefulWidget with memoized event map so the O(N)
/// _buildEventMap computation only runs when [sessions] actually changes,
/// not on every setState (view mode toggle, day selection, etc.).
class _HistoryBody extends StatefulWidget {
  const _HistoryBody({
    required this.sessions,
    required this.viewMode,
    required this.selectedDay,
    required this.focusedDay,
    required this.onDaySelected,
    required this.onRefresh,
  });

  final List<WorkoutSessionSummary> sessions;
  final _ViewMode viewMode;
  final DateTime? selectedDay;
  final DateTime focusedDay;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final Future<void> Function() onRefresh;

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  late Map<DateTime, List<WorkoutSessionSummary>> _eventMap;

  @override
  void initState() {
    super.initState();
    _eventMap = _buildEventMap(widget.sessions);
  }

  @override
  void didUpdateWidget(_HistoryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recompute only when the sessions list reference changes (new Drift
    // emission), not on every parent setState.
    if (!identical(oldWidget.sessions, widget.sessions)) {
      _eventMap = _buildEventMap(widget.sessions);
    }
  }

  Map<DateTime, List<WorkoutSessionSummary>> _buildEventMap(
      List<WorkoutSessionSummary> sessions) {
    final map = <DateTime, List<WorkoutSessionSummary>>{};
    for (final s in sessions) {
      final key = _normalizeDate(s.startedAt);
      map.putIfAbsent(key, () => []).add(s);
    }
    return map;
  }

  /// Issue #8 fix: use local time (not UTC) so the calendar day matches
  /// the date the user sees in the session card's date label.
  DateTime _normalizeDate(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  List<WorkoutSessionSummary> _eventsForDay(DateTime day) {
    return _eventMap[_normalizeDate(day)] ?? [];
  }

  List<WorkoutSessionSummary> get _filteredSessions {
    if (widget.selectedDay == null) return widget.sessions;
    final key = _normalizeDate(widget.selectedDay!);
    return widget.sessions
        .where((s) => _normalizeDate(s.startedAt) == key)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSessions;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        slivers: [
          if (widget.viewMode == _ViewMode.calendar)
            SliverToBoxAdapter(
              child: _CalendarSection(
                selectedDay: widget.selectedDay,
                focusedDay: widget.focusedDay,
                eventsForDay: _eventsForDay,
                onDaySelected: widget.onDaySelected,
              ),
            ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.selectedDay != null
                            ? 'No workouts on this day.'
                            : 'No workouts yet.\nStart a plan to see your history here.',
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) =>
                    SessionHistoryCard(session: filtered[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({
    required this.selectedDay,
    required this.focusedDay,
    required this.eventsForDay,
    required this.onDaySelected,
  });

  final DateTime? selectedDay;
  final DateTime focusedDay;
  final List<WorkoutSessionSummary> Function(DateTime) eventsForDay;
  final void Function(DateTime, DateTime) onDaySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TableCalendar<WorkoutSessionSummary>(
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      eventLoader: eventsForDay,
      onDaySelected: onDaySelected,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      headerStyle: const HeaderStyle(formatButtonVisible: false),
      calendarStyle: CalendarStyle(
        markerDecoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        todayTextStyle:
            TextStyle(color: theme.colorScheme.onPrimaryContainer),
      ),
    );
  }
}
