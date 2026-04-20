import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

class StreakCalendarWidget extends StatelessWidget {
  const StreakCalendarWidget({
    super.key,
    required this.days,
    required this.year,
    required this.month,
  });

  final List<StreakDay> days;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    // Weekday of the 1st day: Monday=1 … Sunday=7 → offset 0-based (Mon=0)
    final firstWeekday = DateTime(year, month, 1).weekday - 1;

    final dayMap = {for (final d in days) d.date: d};

    const headers = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day-of-week headers
        Row(
          children: headers
              .map(
                (h) => Expanded(
                  child: Center(
                    child: Text(
                      h,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: firstWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday) return const SizedBox.shrink();
            final day = index - firstWeekday + 1;
            final dateStr = _formatDate(year, month, day);
            final streakDay = dayMap[dateStr];
            return _DayCell(
              day: day,
              streakDay: streakDay,
              isToday: _isToday(year, month, day),
            );
          },
        ),
        const SizedBox(height: 12),
        // Legend
        _Legend(colorScheme: colorScheme, theme: theme),
      ],
    );
  }

  String _formatDate(int y, int m, int d) {
    return '${y.toString().padLeft(4, '0')}-'
        '${m.toString().padLeft(2, '0')}-'
        '${d.toString().padLeft(2, '0')}';
  }

  bool _isToday(int y, int m, int d) {
    final now = DateTime.now();
    return now.year == y && now.month == m && now.day == d;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.streakDay,
    required this.isToday,
  });

  final int day;
  final StreakDay? streakDay;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    Color? bgColor;
    Color textColor = colorScheme.onSurface;

    if (streakDay != null) {
      switch (streakDay!.status) {
        case StreakDayStatus.completed:
          bgColor = colorScheme.primary;
          textColor = colorScheme.onPrimary;
        case StreakDayStatus.restDay:
          bgColor = colorScheme.surfaceContainerHighest;
          textColor = colorScheme.onSurfaceVariant;
        case StreakDayStatus.missed:
          bgColor = colorScheme.errorContainer;
          textColor = colorScheme.onErrorContainer;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: isToday
            ? Border.all(color: colorScheme.primary, width: 1.5)
            : null,
      ),
      child: Center(
        child: Text(
          day.toString(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColor,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colorScheme, required this.theme});

  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(
          color: colorScheme.primary,
          label: 'Workout',
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(width: 16),
        _LegendItem(
          color: colorScheme.surfaceContainerHighest,
          label: 'Rest',
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(width: 16),
        _LegendItem(
          color: colorScheme.errorContainer,
          label: 'Missed',
          theme: theme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.theme,
    required this.colorScheme,
  });

  final Color color;
  final String label;
  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
