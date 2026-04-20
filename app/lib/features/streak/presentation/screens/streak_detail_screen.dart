import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/streak_providers.dart';
import '../widgets/streak_calendar_widget.dart';

class StreakDetailScreen extends ConsumerStatefulWidget {
  const StreakDetailScreen({super.key});

  @override
  ConsumerState<StreakDetailScreen> createState() => _StreakDetailScreenState();
}

class _StreakDetailScreenState extends ConsumerState<StreakDetailScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _year--;
        _month = 12;
      } else {
        _month--;
      }
    });
  }

  void _nextMonth() {
    if (_isCurrentMonth) return;
    setState(() {
      if (_month == 12) {
        _year++;
        _month = 1;
      } else {
        _month++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final streakAsync = ref.watch(streakStreamProvider);
    final historyAsync = ref.watch(streakHistoryProvider(_year, _month));

    return Scaffold(
      appBar: AppBar(title: const Text('Streak')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(streakStreamProvider);
          ref.invalidate(streakHistoryProvider(_year, _month));
          await Future.wait([
            ref.read(streakStreamProvider.future).catchError((_) => null),
            ref
                .read(streakHistoryProvider(_year, _month).future)
                .catchError((_) => <StreakDay>[]),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // Streak header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: streakAsync.when(
                  loading: () => const _StreakHeaderSkeleton(),
                  error: (e, _) => _ErrorTile(
                    message: 'Could not load streak',
                    onRetry: () => ref.invalidate(streakStreamProvider),
                  ),
                  data: (streak) => streak == null
                      ? const _EmptyStreakHeader()
                      : _StreakHeader(streak: streak),
                ),
              ),
            ),

            // Month navigator + calendar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MonthNavigator(
                          year: _year,
                          month: _month,
                          canGoNext: !_isCurrentMonth,
                          onPrev: _prevMonth,
                          onNext: _nextMonth,
                        ),
                        const SizedBox(height: 12),
                        historyAsync.when(
                          loading: () => const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => _ErrorTile(
                            message: 'Could not load history',
                            onRetry: () => ref
                                .invalidate(streakHistoryProvider(_year, _month)),
                          ),
                          data: (days) => StreakCalendarWidget(
                            days: days,
                            year: _year,
                            month: _month,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streak header
// ---------------------------------------------------------------------------

class _StreakHeader extends StatelessWidget {
  const _StreakHeader({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.local_fire_department,
              size: 56,
              color: Colors.deepOrange,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${streak.currentStreak}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'day streak',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Best: ${streak.longestStreak} days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
                    ),
                  ),
                  if (streak.lastWorkoutDate != null)
                    Text(
                      'Last workout: ${_friendlyDate(streak.lastWorkoutDate!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyDate(String yyyyMmDd) {
    final parts = yyyyMmDd.split('-');
    if (parts.length < 3) return yyyyMmDd;
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null || month < 1 || month > 12) return yyyyMmDd;
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[month]} $day';
  }
}

class _EmptyStreakHeader extends StatelessWidget {
  const _EmptyStreakHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.local_fire_department, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              'No streak yet',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              'Complete your first workout to start a streak!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakHeaderSkeleton extends StatelessWidget {
  const _StreakHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

// ---------------------------------------------------------------------------
// Month navigator
// ---------------------------------------------------------------------------

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.year,
    required this.month,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final int month;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
          tooltip: 'Previous month',
        ),
        Expanded(
          child: Text(
            '${monthNames[month]} $year',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoNext ? onNext : null,
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 32),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
