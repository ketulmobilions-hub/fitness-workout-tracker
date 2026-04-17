import 'package:fl_chart/fl_chart.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/progress_providers.dart';
import '../widgets/date_range_selector.dart';

class ExerciseProgressScreen extends ConsumerStatefulWidget {
  const ExerciseProgressScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
  });

  final String exerciseId;
  final String exerciseName;

  @override
  ConsumerState<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState
    extends ConsumerState<ExerciseProgressScreen> {
  String _period = '3M';

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(
      exerciseProgressProvider(
        widget.exerciseId,
        exercisePeriodToApiParam(_period),
      ),
    );

    // Issue #14: use authoritative name from loaded data; fall back to the
    // name passed via navigation (query param / extra) while loading or on error.
    final title = switch (progressAsync) {
      AsyncData(:final value) => value.exercise.name,
      _ => widget.exerciseName,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          DateRangeSelector(
            options: kExercisePeriods,
            selected: _period,
            onSelected: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: progressAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorBody(
                onRetry: () => ref.invalidate(
                  exerciseProgressProvider(
                    widget.exerciseId,
                    exercisePeriodToApiParam(_period),
                  ),
                ),
              ),
              data: (progress) => _ProgressBody(progress: progress),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main content body
// ---------------------------------------------------------------------------

// Issue #5: StatefulWidget caches sorted lists so they are only recomputed
// when `progress` actually changes (new period loaded), not on every setState
// triggered by the DateRangeSelector while a new period is loading.
class _ProgressBody extends StatefulWidget {
  const _ProgressBody({required this.progress});

  final ExerciseProgress progress;

  @override
  State<_ProgressBody> createState() => _ProgressBodyState();
}

class _ProgressBodyState extends State<_ProgressBody> {
  late List<ExerciseHistoryPoint> _sortedAsc;
  late List<ExerciseHistoryPoint> _sortedDesc;

  @override
  void initState() {
    super.initState();
    _computeSorted();
  }

  @override
  void didUpdateWidget(_ProgressBody old) {
    super.didUpdateWidget(old);
    // ExerciseProgress is a Freezed data class, so `!=` performs deep structural
    // equality — this comparison is correct and only returns true when the server
    // has returned different data (e.g. a new period was loaded). If ExerciseProgress
    // is ever migrated away from Freezed, this guard must be updated.
    if (old.progress != widget.progress) _computeSorted();
  }

  void _computeSorted() {
    _sortedAsc = [...widget.progress.history]
      ..sort((a, b) => _compareDates(a.date, b.date));
    _sortedDesc = [...widget.progress.history]
      ..sort((a, b) => _compareDates(b.date, a.date));
  }

  @override
  Widget build(BuildContext context) {
    final sortedAsc = _sortedAsc;
    final sortedDesc = _sortedDesc;

    return CustomScrollView(
      slivers: [
        // PR summary cards
        SliverToBoxAdapter(
          child: _PrSummarySection(
            prs: widget.progress.personalRecords,
            estimatedOneRepMax: widget.progress.estimatedOneRepMax,
          ),
        ),

        // Weight progression chart
        if (sortedAsc.any((h) => h.maxWeight != null)) ...[
          SliverToBoxAdapter(
            child: _ChartSection(
              title: 'Weight Progression',
              child: _WeightChart(history: sortedAsc),
            ),
          ),
        ],

        // Volume per session chart
        if (sortedAsc.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _ChartSection(
              title: 'Volume Per Session',
              child: _VolumeBarChart(history: sortedAsc),
            ),
          ),
        ],

        // Session history header + rows — Issue #8: SliverList.builder avoids
        // an unbounded Column nested inside a scrollable.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Session History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),

        if (sortedDesc.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No sessions found for this period.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: sortedDesc.length,
              itemBuilder: (_, index) => _HistoryRow(point: sortedDesc[index]),
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }
}

// Issue #12: parse dates with DateTime.tryParse so ISO timestamps with time
// components (e.g. "2025-01-05T14:30:00Z") and plain dates ("2025-01-05") both
// sort correctly. Raw string comparison breaks for any non-YYYY-MM-DD format.
int _compareDates(String a, String b) {
  final dtA = DateTime.tryParse(a);
  final dtB = DateTime.tryParse(b);
  if (dtA == null && dtB == null) return 0;
  if (dtA == null) return 1;
  if (dtB == null) return -1;
  return dtA.compareTo(dtB);
}

// ---------------------------------------------------------------------------
// PR summary cards
// ---------------------------------------------------------------------------

class _PrSummarySection extends StatelessWidget {
  const _PrSummarySection({
    required this.prs,
    required this.estimatedOneRepMax,
  });

  final ExercisePersonalRecords prs;
  final double? estimatedOneRepMax;

  @override
  Widget build(BuildContext context) {
    final tiles = <_PrCard>[];

    if (prs.maxWeight != null) {
      tiles.add(_PrCard(
        label: 'Max Weight',
        value: '${prs.maxWeight!.toStringAsFixed(1)} kg',
        icon: Icons.fitness_center,
      ));
    }
    if (prs.maxReps != null) {
      tiles.add(_PrCard(
        label: 'Max Reps',
        value: '${prs.maxReps!.toInt()} reps',
        icon: Icons.repeat,
      ));
    }
    if (prs.maxVolume != null) {
      tiles.add(_PrCard(
        label: 'Max Volume',
        value: '${prs.maxVolume!.toStringAsFixed(0)} kg',
        icon: Icons.bar_chart,
      ));
    }
    if (prs.bestPace != null) {
      tiles.add(_PrCard(
        label: 'Best Pace',
        value: _formatPace(prs.bestPace!),
        icon: Icons.speed,
      ));
    }

    if (tiles.isEmpty && estimatedOneRepMax == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No records yet for this period.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tiles.isNotEmpty) ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: tiles,
            ),
          ],
          if (estimatedOneRepMax != null) ...[
            const SizedBox(height: 8),
            _OneRepMaxBadge(value: estimatedOneRepMax!),
          ],
        ],
      ),
    );
  }

  String _formatPace(double secPerKm) {
    final min = (secPerKm / 60).floor();
    final sec = (secPerKm % 60).toInt();
    return '$min:${sec.toString().padLeft(2, '0')}/km';
  }
}

class _PrCard extends StatelessWidget {
  const _PrCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
}

class _OneRepMaxBadge extends StatelessWidget {
  const _OneRepMaxBadge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      color: colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, color: colorScheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated 1RM',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onTertiaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '${value.toStringAsFixed(1)} kg',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weight progression chart
// ---------------------------------------------------------------------------

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.history});

  final List<ExerciseHistoryPoint> history;

  @override
  Widget build(BuildContext context) {
    final points = history
        .where((h) => h.maxWeight != null)
        .toList();

    if (points.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.maxWeight!);
    }).toList();

    final maxWeight = points
        .map((p) => p.maxWeight!)
        .reduce((a, b) => a > b ? a : b);
    final minWeight = points
        .map((p) => p.maxWeight!)
        .reduce((a, b) => a < b ? a : b);
    final padding = (maxWeight - minWeight) * 0.2 + 5;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          // Issue #7: use 0.0 (double) not 0 (int) so clamp returns double,
          // matching fl_chart's expected type for minY.
          minY: (minWeight - padding).clamp(0.0, double.infinity),
          maxY: maxWeight + padding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: colorScheme.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: colorScheme.primary,
                  strokeWidth: 0,
                ),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '${value.toStringAsFixed(0)} kg',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: _labelInterval(points.length).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _shortDate(points[index].date),
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                // Issue #9: guard against fl_chart passing a stale x value
                // outside the current data range (e.g. after period change).
                final index = spot.x.toInt();
                if (index < 0 || index >= points.length) return null;
                final point = points[index];
                return LineTooltipItem(
                  '${point.maxWeight!.toStringAsFixed(1)} kg\n${point.date}',
                  TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  int _labelInterval(int count) {
    if (count <= 6) return 1;
    if (count <= 12) return 2;
    return (count / 6).ceil();
  }

  String _shortDate(String date) {
    final parts = date.split('-');
    if (parts.length < 3) return date;
    // Issue #10: return raw string on parse failure so a bad date string
    // never causes an out-of-range index into abbr[].
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null || month < 1 || month > 12) return date;
    const abbr = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${abbr[month]} $day';
  }
}

// ---------------------------------------------------------------------------
// Volume per session bar chart
// ---------------------------------------------------------------------------

class _VolumeBarChart extends StatelessWidget {
  const _VolumeBarChart({required this.history});

  final List<ExerciseHistoryPoint> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final maxVolume =
        history.map((h) => h.totalVolume).fold(0.0, (a, b) => a > b ? a : b);

    // Issue #4 / #6: for bodyweight exercises every session has totalVolume == 0.
    // Rendering bars of height 0 against an arbitrary Y-axis looks broken.
    // Show an explanatory message instead of an empty-looking chart.
    if (maxVolume == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No weighted volume — this exercise is bodyweight.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final barGroups = history.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.totalVolume,
            color: colorScheme.primary,
            width: history.length > 20 ? 4 : 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxVolume * 1.2,
          barGroups: barGroups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == 0) {
                    return const SizedBox.shrink();
                  }
                  final label = value >= 1000
                      ? '${(value / 1000).toStringAsFixed(1)}k'
                      : value.toStringAsFixed(0);
                  return Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) {
                // Issue #9: guard against stale group index after period change.
                final index = group.x;
                if (index < 0 || index >= history.length) return null;
                final point = history[index];
                return BarTooltipItem(
                  '${rod.toY.toStringAsFixed(0)} kg\n${point.date}',
                  TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.point});

  final ExerciseHistoryPoint point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              point.date,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (point.maxWeight != null)
            Expanded(
              flex: 2,
              child: Text(
                '${point.maxWeight!.toStringAsFixed(1)} kg',
                style: theme.textTheme.bodySmall,
              ),
            ),
          Expanded(
            flex: 2,
            child: Text(
              '${point.totalReps} reps',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${point.totalVolume.toStringAsFixed(0)} kg vol',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart section wrapper
// ---------------------------------------------------------------------------

class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load exercise progress.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
