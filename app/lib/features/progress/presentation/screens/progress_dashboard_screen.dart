import 'package:fl_chart/fl_chart.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../providers/progress_providers.dart';
import '../widgets/date_range_selector.dart';

class ProgressDashboardScreen extends ConsumerStatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  ConsumerState<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState
    extends ConsumerState<ProgressDashboardScreen> {
  String _volumePeriod = '1M';

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(progressOverviewProvider);
    final recordsAsync = ref.watch(personalRecordsProvider);
    final volumeAsync = ref.watch(
      volumeDataProvider(volumePeriodToApiParam(_volumePeriod)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: RefreshIndicator(
        onRefresh: () async {
          // Capture the period now so that a chip tap mid-refresh (Issue #3)
          // doesn't change which future we await — we always wait for the
          // period that was active when the gesture started, then the widget's
          // own ref.watch picks up the new period independently.
          final volumeKey = volumePeriodToApiParam(_volumePeriod);
          await Future.wait([
            ref.read(progressOverviewProvider.notifier).refresh(),
            ref.read(personalRecordsProvider.notifier).refresh(),
            // ref.refresh atomically invalidates and returns the new future,
            // avoiding the separate invalidate + read(.future) race.
            ref.refresh(volumeDataProvider(volumeKey).future),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            // Streak + overview stats
            SliverToBoxAdapter(
              child: overviewAsync.when(
                loading: () =>
                    const _SectionSkeleton(height: 160, label: 'Loading stats…'),
                error: (e, _) => _ErrorTile(
                  message: 'Could not load stats',
                  onRetry: () => ref
                      .read(progressOverviewProvider.notifier)
                      .refresh(),
                ),
                data: (overview) => _OverviewSection(overview: overview),
              ),
            ),

            // Volume chart
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Volume Trend',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DateRangeSelector(
                      options: kVolumePeriods,
                      selected: _volumePeriod,
                      onSelected: (p) => setState(() => _volumePeriod = p),
                    ),
                    const SizedBox(height: 16),
                    volumeAsync.when(
                      loading: () => const _ChartSkeleton(),
                      error: (e, _) => const _ChartError(),
                      data: (data) => _VolumeChart(data: data),
                    ),
                  ],
                ),
              ),
            ),

            // Personal records
            SliverToBoxAdapter(
              child: _SectionCard(
                title: 'Personal Records',
                child: recordsAsync.when(
                  loading: () =>
                      const _SectionSkeleton(height: 120, label: 'Loading PRs…'),
                  error: (e, _) => _ErrorTile(
                    message: 'Could not load personal records',
                    onRetry: () => ref
                        .read(personalRecordsProvider.notifier)
                        .refresh(),
                  ),
                  data: (records) => _PersonalRecordsList(records: records),
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
// Overview section — streak card + stats grid
// ---------------------------------------------------------------------------

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.overview});

  final ProgressOverview overview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StreakCard(overview: overview),
          const SizedBox(height: 12),
          _StatsGrid(overview: overview),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.overview});

  final ProgressOverview overview;

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
              size: 40,
              color: Colors.deepOrange,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${overview.currentStreak} day streak',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'Longest: ${overview.longestStreak} days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.7,
                      ),
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.overview});

  final ProgressOverview overview;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Total Workouts',
            value: overview.totalWorkouts.toString(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Volume This Week',
            value: '${_formatVolume(overview.volumeThisWeek)} kg',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Volume This Month',
            value: '${_formatVolume(overview.volumeThisMonth)} kg',
          ),
        ),
      ],
    );
  }

  String _formatVolume(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Volume chart
// ---------------------------------------------------------------------------

class _VolumeChart extends StatelessWidget {
  const _VolumeChart({required this.data});

  final VolumeData data;

  @override
  Widget build(BuildContext context) {
    final buckets = data.buckets;

    if (buckets.isEmpty) {
      return const _ChartEmpty(message: 'No workout data for this period.');
    }

    final colorScheme = Theme.of(context).colorScheme;
    final spots = buckets.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.volume);
    }).toList();

    final maxVolume =
        buckets.map((b) => b.volume).fold(0.0, (a, b) => a > b ? a : b);

    // Issue #4: when all sessions in the period are bodyweight-only, every
    // bucket has volume == 0. Rendering a chart with maxY == 0 causes a
    // fl_chart assertion. Show an explanatory empty state instead — a chart
    // with a "10 kg" Y-axis but invisible zero-height bars is more confusing
    // than a clear message.
    if (maxVolume == 0) {
      return const _ChartEmpty(
        message: 'No weighted volume this period.\nBodyweight sessions record reps, not kg.',
      );
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxVolume * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: colorScheme.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.primary.withValues(alpha: 0.1),
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
                reservedSize: 52,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
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
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: _labelInterval(buckets.length).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= buckets.length) {
                    return const SizedBox.shrink();
                  }
                  final date = buckets[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _shortDate(date),
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
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  // Issue #9: guard against out-of-range touch events that
                  // fl_chart can produce near chart padding boundaries.
                  final index = spot.x.toInt();
                  if (index < 0 || index >= buckets.length) return null;
                  final bucket = buckets[index];
                  return LineTooltipItem(
                    '${bucket.volume.toStringAsFixed(0)} kg\n'
                    '${bucket.sessions} session${bucket.sessions == 1 ? '' : 's'}',
                    TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  int _labelInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 30) return 5;
    return (count / 6).ceil();
  }

  // Issue #10: return the raw string on parse failure rather than silently
  // producing a garbage label like ' 0' when the month index is 0.
  String _shortDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length < 3) return isoDate;
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null || month < 1 || month > 12) {
      return isoDate;
    }
    const monthAbbr = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${monthAbbr[month]} $day';
  }
}

// ---------------------------------------------------------------------------
// Personal records list
// ---------------------------------------------------------------------------

// Issue #6: changed from ConsumerWidget to StatelessWidget — ref was never
// used inside build(); navigation uses BuildContext, not Riverpod.
class _PersonalRecordsList extends StatelessWidget {
  const _PersonalRecordsList({required this.records});

  final List<ProgressPersonalRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No personal records yet.\nComplete workouts to set records!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Records are pre-sorted by PersonalRecordsNotifier._sortByMostRecent
    // (Issue #8): no sort here, so unrelated setState calls (e.g. period chip
    // taps) no longer trigger a full DateTime.tryParse sort pass on every frame.
    return Column(
      children: records.map((pr) {
        return _PersonalRecordTile(
          record: pr,
          onTap: () => context.push(
            AppRoutes.exerciseProgressPath(pr.exerciseId, name: pr.exerciseName),
          ),
        );
      }).toList(),
    );
  }
}

class _PersonalRecordTile extends StatelessWidget {
  const _PersonalRecordTile({required this.record, required this.onTap});

  final ProgressPersonalRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        child: Icon(
          _iconForType(record.recordType),
          color: colorScheme.onSecondaryContainer,
          size: 18,
        ),
      ),
      title: Text(
        record.exerciseName,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _typeLabel(record.recordType),
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        _formatValue(record.recordType, record.value),
        style: theme.textTheme.titleSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'max_weight' => Icons.fitness_center,
      'max_reps' => Icons.repeat,
      'max_volume' => Icons.bar_chart,
      'best_pace' => Icons.speed,
      _ => Icons.emoji_events,
    };
  }

  String _typeLabel(String type) {
    return switch (type) {
      'max_weight' => 'Max Weight',
      'max_reps' => 'Max Reps',
      'max_volume' => 'Max Volume',
      'best_pace' => 'Best Pace',
      _ => type,
    };
  }

  String _formatValue(String type, double value) {
    return switch (type) {
      'max_weight' => '${value.toStringAsFixed(1)} kg',
      'max_reps' => '${value.toInt()} reps',
      'max_volume' => '${value.toStringAsFixed(0)} kg',
      'best_pace' => _formatPace(value),
      _ => value.toStringAsFixed(1),
    };
  }

  String _formatPace(double secPerKm) {
    final min = (secPerKm / 60).floor();
    final sec = (secPerKm % 60).toInt();
    return '$min:${sec.toString().padLeft(2, '0')}/km';
  }
}

// ---------------------------------------------------------------------------
// Shared layout helpers
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton({required this.height, required this.label});

  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Issue #13: label was accepted but never rendered — dead code and silent
    // accessibility gap. Now shown beneath the spinner and surfaced to screen
    // readers via Semantics so VoiceOver/TalkBack can announce loading state.
    return Semantics(
      label: label,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ChartError extends StatelessWidget {
  const _ChartError();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load chart data',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
