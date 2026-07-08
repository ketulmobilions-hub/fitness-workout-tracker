import 'package:fl_chart/fl_chart.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/guest_feature_gate.dart';
import '../../../auth/providers/auth_notifier.dart';
import '../../../auth/providers/auth_state.dart';
import '../../../pr_share/pr_share.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../streak/providers/streak_providers.dart';
import '../../providers/progress_providers.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/one_rm_calculator_widget.dart';

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
    // Progress is gated to full accounts server-side (requireFullAccount → 403).
    // Short-circuit for guests before watching any progress provider, so the
    // forbidden endpoints are never called.
    if (ref.watch(authProvider) is AuthGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progress')),
        body: const GuestFeatureGate(
          icon: Icons.insights_outlined,
          title: 'Progress is a member feature',
          message:
              'Create a free account to track your lifts, PRs, and volume over time.',
        ),
      );
    }

    final overviewAsync = ref.watch(progressOverviewProvider);
    final recordsAsync = ref.watch(personalRecordsProvider);
    final volumeAsync = ref.watch(
      volumeDataProvider(volumePeriodToApiParam(_volumePeriod)),
    );
    final profileAsync = ref.watch(profileStreamProvider);
    final scoreSystem = profileAsync.value?.preferences.scoreSystem ?? ScoreSystem.dots;

    // Trigger milestone celebration when a new milestone is reached.
    ref.listen(streakStreamProvider, (_, next) {
      if (next is AsyncData<Streak?> && next.value != null) {
        ref
            .read(milestoneProvider.notifier)
            .maybeUnlock(next.value!.currentStreak);
      }
    });
    ref.listen(milestoneProvider, (_, milestone) {
      if (milestone != null && context.mounted) {
        _showMilestoneCelebration(context, milestone);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('oneRmCalcFab'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const OneRmCalculatorWidget(),
        ),
        icon: const Icon(Icons.calculate_outlined),
        label: const Text('1RM Calc'),
      ),
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
            ref.read(sbdTotalProvider.notifier).refresh(),
            ref.read(strengthScoreHistoryProvider.notifier).refresh(),
            ref.read(volumeZoneProvider.notifier).refresh(),
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

            // SBD total card — shows all-time bests and 12-month trend.
            const SliverToBoxAdapter(
              child: _SbdTotalCard(),
            ),

            // Strength score card — only rendered when data is available.
            // whenOrNull returns null for loading/error states; fall back to
            // SizedBox.shrink() so no gap appears while the overview loads.
            SliverToBoxAdapter(
              child: overviewAsync.whenOrNull(
                data: (overview) => _StrengthScoreCard(
                  overview: overview,
                  scoreSystem: scoreSystem,
                ),
              ) ?? const SizedBox.shrink(),
            ),

            // Strength score trend chart
            SliverToBoxAdapter(
              child: _StrengthScoreTrendCard(scoreSystem: scoreSystem),
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

            // Volume zone analysis — intensity distribution for competition lifts
            const SliverToBoxAdapter(
              child: _VolumeZoneCard(),
            ),

            // Strength balance ratios — collapsible, below main charts
            const SliverToBoxAdapter(
              child: _StrengthBalanceCard(),
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
                  data: (records) => _PersonalRecordsList(
                    records: records,
                    athleteName: profileAsync.value?.displayName,
                  ),
                ),
              ),
            ),

            // Competition history shortcut
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: const Text('Competition History'),
                  subtitle: const Text('Past meet results & Wilks/Dots trend'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.competitionHistory),
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

void _showMilestoneCelebration(BuildContext context, int milestone) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.local_fire_department,
        size: 48,
        color: Colors.deepOrange,
      ),
      title: Text('$milestone-Day Streak!'),
      content: Text(
        "Congratulations! You've reached a $milestone-day streak. Keep it up!",
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Awesome!'),
        ),
      ],
    ),
  );
}

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection({required this.overview});

  final ProgressOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakStreamProvider);
    final Streak? streak = streakAsync.maybeWhen(
      data: (v) => v,
      orElse: () => null,
    );

    final today = _todayString();
    final atRisk = streak != null &&
        streak.currentStreak > 0 &&
        streak.lastWorkoutDate != today;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StreakCard(overview: overview),
          if (atRisk) ...[
            const SizedBox(height: 8),
            const _StreakWarningBanner(),
          ],
          const SizedBox(height: 12),
          _StatsGrid(overview: overview),
        ],
      ),
    );
  }

  String _todayString() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.streak),
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
              Icon(
                Icons.chevron_right,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakWarningBanner extends StatelessWidget {
  const _StreakWarningBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.onTertiaryContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Work out today to keep your streak alive!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
// SBD total card
// ---------------------------------------------------------------------------

class _SbdTotalCard extends ConsumerWidget {
  const _SbdTotalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sbdAsync = ref.watch(sbdTotalProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return sbdAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SBD Total',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const _ChartSkeleton(),
              ],
            ),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SBD Total',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _ErrorTile(
                  message: 'Could not load SBD total',
                  onRetry: () =>
                      ref.read(sbdTotalProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (sbd) {
        // Need at least 1 lift logged to show anything useful.
        if (sbd.liftCount == 0) return const SizedBox.shrink();

        final delta = sbd.monthOverMonthDelta;
        final hasTrend = sbd.monthly.length >= 2;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'SBD Total',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (delta != null) ...[
                        const Spacer(),
                        _DeltaChip(
                          delta: delta,
                          vsMonth: sbd.deltaVsMonth,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Big total number
                  if (sbd.total != null)
                    Text(
                      '${sbd.total!.toStringAsFixed(1)} kg',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    )
                  else
                    Text(
                      'Partial total',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Individual lift bests
                  _LiftRow(
                      label: 'Squat',
                      value: sbd.squat,
                      icon: Icons.fitness_center),
                  _LiftRow(
                      label: 'Bench',
                      value: sbd.bench,
                      icon: Icons.sports_gymnastics),
                  _LiftRow(
                      label: 'Deadlift',
                      value: sbd.deadlift,
                      icon: Icons.hardware),

                  // Trend chart — only when ≥ 2 complete monthly points exist.
                  if (hasTrend) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Text(
                      'Monthly Trend',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SbdTrendChart(monthly: sbd.monthly),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta, this.vsMonth});

  final double delta;
  final String? vsMonth; // 'YYYY-MM' — shown as "vs Jan" suffix

  // Fix #6: delta == 0.0 was rendered as green "+0.0 kg" which falsely implies
  // progress. Zero is neutral; negative is red; positive is green.
  Color _color(ColorScheme cs) {
    if (delta > 0) return Colors.green;
    if (delta < 0) return cs.error;
    return cs.onSurfaceVariant;
  }

  String get _sign {
    if (delta > 0) return '+';
    if (delta == 0.0) return '±';
    return '';
  }

  // Format 'YYYY-MM' → 'Jan' for the "vs Jan" label.
  String? _vsLabel() {
    if (vsMonth == null) return null;
    final parts = vsMonth!.split('-');
    if (parts.length < 2) return null;
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return null;
    const abbr = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return abbr[m];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _color(cs);
    final label = _vsLabel();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label != null
            ? '$_sign${delta.toStringAsFixed(1)} kg vs $label'
            : '$_sign${delta.toStringAsFixed(1)} kg',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _LiftRow extends StatelessWidget {
  const _LiftRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final double? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(
            value != null ? '${value!.toStringAsFixed(1)} kg' : '—',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: value != null ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SbdTrendChart extends StatelessWidget {
  const _SbdTrendChart({required this.monthly});

  final List<SbdMonthPoint> monthly;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Fix #8: SbdMonthPoint.total was removed from the domain model — compute
    // here to avoid carrying derivable state that could be inconsistent.
    double pointTotal(SbdMonthPoint p) => p.squat + p.bench + p.deadlift;

    final spots = monthly
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), pointTotal(e.value)))
        .toList();

    final totals = monthly.map(pointTotal).toList();
    final minTotal = totals.reduce((a, b) => a < b ? a : b);
    final maxTotal = totals.reduce((a, b) => a > b ? a : b);
    final chartMinY = (minTotal - 20).clamp(0.0, double.infinity);
    final chartMaxY = maxTotal + 30;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: chartMinY,
          maxY: chartMaxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: cs.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: cs.primary,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: cs.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.4),
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
                    value.toInt().toString(),
                    style:
                        TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (spots.length / 4).ceilToDouble().clamp(1.0, 12.0),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= monthly.length) {
                    return const SizedBox.shrink();
                  }
                  final parts = monthly[idx].month.split('-');
                  if (parts.length < 2) return const SizedBox.shrink();
                  final m = int.tryParse(parts[1]);
                  if (m == null || m < 1 || m > 12) {
                    return const SizedBox.shrink();
                  }
                  const abbr = [
                    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      abbr[m],
                      style: TextStyle(
                          fontSize: 10, color: cs.onSurfaceVariant),
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
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= monthly.length) return null;
                final p = monthly[idx];
                final t = p.squat + p.bench + p.deadlift;
                return LineTooltipItem(
                  '${p.month}\n${t.toStringAsFixed(1)} kg total\n'
                  'S ${p.squat.toStringAsFixed(1)} / '
                  'B ${p.bench.toStringAsFixed(1)} / '
                  'D ${p.deadlift.toStringAsFixed(1)}',
                  TextStyle(color: cs.onPrimary, fontSize: 11),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Strength score card
// ---------------------------------------------------------------------------

class _StrengthScoreCard extends StatelessWidget {
  const _StrengthScoreCard({
    required this.overview,
    required this.scoreSystem,
  });

  final ProgressOverview overview;
  final ScoreSystem scoreSystem;

  double? get _score => switch (scoreSystem) {
    ScoreSystem.wilks => overview.wilks,
    ScoreSystem.dots => overview.dots,
    ScoreSystem.ipfGl => overview.ipfGl,
  };

  String get _label => switch (scoreSystem) {
    ScoreSystem.wilks => 'Wilks',
    ScoreSystem.dots => 'Dots',
    ScoreSystem.ipfGl => 'IPF GL',
  };

  // IPF GL uses a ~60–120 scale; Wilks/Dots use a ~200–500 scale.
  // Separate thresholds prevent IPF GL athletes from always showing 'Beginner'.
  String _bandLabel(double score) {
    if (scoreSystem == ScoreSystem.ipfGl) {
      if (score >= 85) return 'Elite';
      if (score >= 70) return 'Advanced';
      if (score >= 50) return 'Intermediate';
      return 'Beginner';
    }
    if (score >= 400) return 'Elite';
    if (score >= 300) return 'Advanced';
    if (score >= 200) return 'Intermediate';
    return 'Beginner';
  }

  Color _bandColor(double score, ColorScheme cs) {
    final band = _bandLabel(score);
    return switch (band) {
      'Elite' => Colors.purple,
      'Advanced' => cs.primary,
      'Intermediate' => Colors.orange,
      _ => cs.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    // Only show the card when the score is available — avoids a confusing
    // empty placeholder for athletes who haven't set up their competition
    // profile or logged SBD lifts yet.
    if (score == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final band = _bandLabel(score);
    final bandColor = _bandColor(score, cs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.leaderboard_outlined, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Strength Score',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score.toStringAsFixed(1),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bandColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      band,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: bandColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BenchmarkBar(score: score, scoreSystem: scoreSystem),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Beginner', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  Text(
                    scoreSystem == ScoreSystem.ipfGl ? 'Elite (85+)' : 'Elite (400+)',
                    style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenchmarkBar extends StatelessWidget {
  const _BenchmarkBar({required this.score, required this.scoreSystem});

  final double score;
  final ScoreSystem scoreSystem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Scale the progress bar to the relevant max for each system so the
    // indicator position is visually meaningful across different score ranges.
    final maxScore = scoreSystem == ScoreSystem.ipfGl ? 120.0 : 500.0;
    final progress = (score / maxScore).clamp(0.0, 1.0);
    final isElite = scoreSystem == ScoreSystem.ipfGl ? score >= 85 : score >= 400;
    final isAdvanced = scoreSystem == ScoreSystem.ipfGl ? score >= 70 : score >= 300;
    final isIntermediate = scoreSystem == ScoreSystem.ipfGl ? score >= 50 : score >= 200;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 8,
        backgroundColor: cs.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(
          isElite
              ? Colors.purple
              : isAdvanced
                  ? cs.primary
                  : isIntermediate
                      ? Colors.orange
                      : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Strength score trend chart
// ---------------------------------------------------------------------------

class _StrengthScoreTrendCard extends ConsumerWidget {
  const _StrengthScoreTrendCard({required this.scoreSystem});

  final ScoreSystem scoreSystem;

  /// Most-recent non-null score for [scoreSystem] across [points].
  /// Scans in reverse so it matches the rightmost dot on the chart.
  double? _latestScore(List<ScoreHistoryPoint> points) {
    for (var i = points.length - 1; i >= 0; i--) {
      final s = switch (scoreSystem) {
        ScoreSystem.wilks => points[i].wilks,
        ScoreSystem.dots => points[i].dots,
        ScoreSystem.ipfGl => points[i].ipfGl,
      };
      if (s != null) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(strengthScoreHistoryProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return historyAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Score Trend',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const _ChartSkeleton(),
              ],
            ),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Score Trend',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _ErrorTile(
                  message: 'Could not load score history',
                  onRetry: () => ref
                      .read(strengthScoreHistoryProvider.notifier)
                      .refresh(),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (history) {
        final points = history.points;

        // Require at least 2 scored months to form a meaningful trend line.
        // Fewer points = no chart, no empty placeholder.
        final latestScore = _latestScore(points);
        final scoredCount = points.where((p) {
          final s = switch (scoreSystem) {
            ScoreSystem.wilks => p.wilks,
            ScoreSystem.dots => p.dots,
            ScoreSystem.ipfGl => p.ipfGl,
          };
          return s != null;
        }).length;

        if (latestScore == null || scoredCount < 2) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.show_chart, size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Score Trend',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      // Chip derived from same rightmost-dot logic as chart —
                      // consistent even when recent months have null scores.
                      _ScoreCategoryChip(
                        score: latestScore,
                        scoreSystem: scoreSystem,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ScoreTrendChart(
                    points: points,
                    scoreSystem: scoreSystem,
                  ),
                  const SizedBox(height: 8),
                  // Bodyweight disclaimer — scores use the current profile
                  // bodyweight for all historical months (no history table yet).
                  Text(
                    '* Based on current bodyweight',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreCategoryChip extends StatelessWidget {
  const _ScoreCategoryChip({
    required this.score,
    required this.scoreSystem,
  });

  final double score;
  final ScoreSystem scoreSystem;

  String get _label {
    if (scoreSystem == ScoreSystem.ipfGl) {
      if (score >= 85) return 'Elite';
      if (score >= 70) return 'Advanced';
      if (score >= 50) return 'Intermediate';
      return 'Beginner';
    }
    if (score >= 400) return 'Elite';
    if (score >= 300) return 'Advanced';
    if (score >= 200) return 'Intermediate';
    return 'Beginner';
  }

  Color _color(ColorScheme cs) {
    return switch (_label) {
      'Elite' => Colors.purple,
      'Advanced' => cs.primary,
      'Intermediate' => Colors.orange,
      _ => cs.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _color(cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _ScoreTrendChart extends StatelessWidget {
  const _ScoreTrendChart({
    required this.points,
    required this.scoreSystem,
  });

  final List<ScoreHistoryPoint> points;
  final ScoreSystem scoreSystem;

  // Benchmark thresholds per scoring system (beginner/intermediate/advanced boundaries).
  List<double> get _benchmarks => scoreSystem == ScoreSystem.ipfGl
      ? [50, 70, 85]
      : [200, 300, 400];

  double get _maxY => scoreSystem == ScoreSystem.ipfGl ? 120 : 500;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final indexedScores = <int, double>{};
    for (var i = 0; i < points.length; i++) {
      final s = switch (scoreSystem) {
        ScoreSystem.wilks => points[i].wilks,
        ScoreSystem.dots => points[i].dots,
        ScoreSystem.ipfGl => points[i].ipfGl,
      };
      if (s != null) indexedScores[i] = s;
    }

    final spots = indexedScores.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    if (spots.length < 2) return const SizedBox.shrink();

    final allScores = indexedScores.values.toList();
    final minScore = allScores.reduce((a, b) => a < b ? a : b);
    final maxScore = allScores.reduce((a, b) => a > b ? a : b);
    // Pad the Y axis so benchmark lines and the line itself don't sit on edges.
    final chartMinY = (minScore - 20).clamp(0, _maxY);
    final chartMaxY = (maxScore + 30).clamp(0, _maxY);

    final benchmarkColors = [
      cs.onSurfaceVariant,
      Colors.orange,
      cs.primary,
    ];

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: chartMinY.toDouble(),
          maxY: chartMaxY.toDouble(),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              for (var i = 0; i < _benchmarks.length; i++)
                if (_benchmarks[i] >= chartMinY && _benchmarks[i] <= chartMaxY)
                  HorizontalLine(
                    y: _benchmarks[i],
                    color: benchmarkColors[i].withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      style: TextStyle(
                        fontSize: 9,
                        color: benchmarkColors[i].withValues(alpha: 0.7),
                      ),
                      labelResolver: (_) => _benchmarks[i].toInt().toString(),
                    ),
                  ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: cs.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: cs.primary,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: cs.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (spots.length / 4).ceilToDouble().clamp(1.0, 12.0),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final month = points[idx].month; // 'YYYY-MM'
                  final parts = month.split('-');
                  if (parts.length < 2) return const SizedBox.shrink();
                  final m = int.tryParse(parts[1]);
                  if (m == null || m < 1 || m > 12) {
                    return const SizedBox.shrink();
                  }
                  const abbr = [
                    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      abbr[m],
                      style:
                          TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
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
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= points.length) return null;
                final p = points[idx];
                final label = switch (scoreSystem) {
                  ScoreSystem.wilks => 'Wilks',
                  ScoreSystem.dots => 'Dots',
                  ScoreSystem.ipfGl => 'IPF GL',
                };
                return LineTooltipItem(
                  '${p.month}\n${spot.y.toStringAsFixed(1)} $label',
                  TextStyle(color: cs.onPrimary, fontSize: 12),
                );
              }).toList(),
            ),
          ),
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
// Volume zone card — intensity zone breakdown for competition lifts
// ---------------------------------------------------------------------------

enum _ZoneViewMode { sets, tonnage }

class _VolumeZoneCard extends ConsumerStatefulWidget {
  const _VolumeZoneCard();

  @override
  ConsumerState<_VolumeZoneCard> createState() => _VolumeZoneCardState();
}

class _VolumeZoneCardState extends ConsumerState<_VolumeZoneCard> {
  _ZoneViewMode _mode = _ZoneViewMode.sets;

  static const _techniqueColor = Color(0xFF64B5F6);   // blue 300
  static const _hypertrophyColor = Color(0xFF81C784); // green 300
  static const _strengthColor = Color(0xFFFFB74D);    // orange 300
  static const _maxEffortColor = Color(0xFFE57373);   // red 300

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(volumeZoneProvider);
    return _SectionCard(
      title: 'Intensity Zone Distribution',
      child: async.when(
        loading: () => const _SectionSkeleton(height: 200, label: 'Loading zones…'),
        error: (e, _) => _ErrorTile(
          message: 'Could not load zone data',
          onRetry: () => ref.read(volumeZoneProvider.notifier).refresh(),
        ),
        data: (analysis) {
          if (analysis.data.isEmpty) {
            return const _ChartEmpty(
              message:
                  'No competition-lift data yet.\nLog squat, bench or deadlift sessions to see your intensity zones.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ZoneLegend(
                mode: _mode,
                onModeChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 12),
              _ZoneChart(
                weeks: analysis.data,
                mode: _mode,
                techniqueColor: _techniqueColor,
                hypertrophyColor: _hypertrophyColor,
                strengthColor: _strengthColor,
                maxEffortColor: _maxEffortColor,
              ),
              const SizedBox(height: 12),
              _ZoneSummary(weeks: analysis.data),
            ],
          );
        },
      ),
    );
  }
}

class _ZoneLegend extends StatelessWidget {
  const _ZoneLegend({required this.mode, required this.onModeChanged});

  final _ZoneViewMode mode;
  final ValueChanged<_ZoneViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: const [
              _LegendDot(color: Color(0xFF64B5F6), label: 'Technique'),
              _LegendDot(color: Color(0xFF81C784), label: 'Hypertrophy'),
              _LegendDot(color: Color(0xFFFFB74D), label: 'Strength'),
              _LegendDot(color: Color(0xFFE57373), label: 'Max Effort'),
            ],
          ),
        ),
        SegmentedButton<_ZoneViewMode>(
          segments: const [
            ButtonSegment(value: _ZoneViewMode.sets, label: Text('Sets')),
            ButtonSegment(value: _ZoneViewMode.tonnage, label: Text('Tonnage')),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onModeChanged(s.first),
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStyle: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ZoneChart extends StatelessWidget {
  const _ZoneChart({
    required this.weeks,
    required this.mode,
    required this.techniqueColor,
    required this.hypertrophyColor,
    required this.strengthColor,
    required this.maxEffortColor,
  });

  final List<VolumeZoneWeek> weeks;
  final _ZoneViewMode mode;
  final Color techniqueColor;
  final Color hypertrophyColor;
  final Color strengthColor;
  final Color maxEffortColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTonnage = mode == _ZoneViewMode.tonnage;

    // Map from x-index to week for tooltips and labels — avoids positional
    // index issues if weeks are filtered in the future.
    final xToWeek = <int, VolumeZoneWeek>{};
    final groups = <BarChartGroupData>[];

    for (var i = 0; i < weeks.length; i++) {
      final w = weeks[i];
      xToWeek[i] = w;

      final t = isTonnage ? w.techniqueTonnageKg : w.techniqueSets.toDouble();
      final h = isTonnage ? w.hypertrophyTonnageKg : w.hypertrophySets.toDouble();
      final s = isTonnage ? w.strengthTonnageKg : w.strengthSets.toDouble();
      final m = isTonnage ? w.maxEffortTonnageKg : w.maxEffortSets.toDouble();
      final total = t + h + s + m;

      final opacity = w.isDeload ? 0.45 : 1.0;

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: total,
              width: weeks.length > 24 ? 6 : (weeks.length > 16 ? 10 : 14),
              rodStackItems: [
                BarChartRodStackItem(0, t, techniqueColor.withValues(alpha: opacity)),
                BarChartRodStackItem(t, t + h, hypertrophyColor.withValues(alpha: opacity)),
                BarChartRodStackItem(t + h, t + h + s, strengthColor.withValues(alpha: opacity)),
                BarChartRodStackItem(t + h + s, total, maxEffortColor.withValues(alpha: opacity)),
              ],
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: groups,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  final week = xToWeek[idx];
                  if (week == null) return const SizedBox.shrink();

                  // Show label only at start, middle, and end to avoid clutter.
                  final total = weeks.length;
                  final showLabel = idx == 0 ||
                      idx == total - 1 ||
                      (total > 4 && idx == (total / 2).round());
                  if (!showLabel) return const SizedBox.shrink();

                  final d = week.weekStart;
                  const m = [
                    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${m[d.month]} ${d.day}',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final week = xToWeek[group.x];
                if (week == null) return null;
                final d = week.weekStart;
                const mo = [
                  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                ];
                final header = '${mo[d.month]} ${d.day}${week.isDeload ? ' (deload)' : ''}';
                final suffix = isTonnage ? ' kg' : ' sets';
                final t = isTonnage ? week.techniqueTonnageKg : week.techniqueSets.toDouble();
                final h = isTonnage ? week.hypertrophyTonnageKg : week.hypertrophySets.toDouble();
                final s = isTonnage ? week.strengthTonnageKg : week.strengthSets.toDouble();
                final m = isTonnage ? week.maxEffortTonnageKg : week.maxEffortSets.toDouble();
                return BarTooltipItem(
                  '$header\n'
                  'Technique: ${t.toStringAsFixed(isTonnage ? 1 : 0)}$suffix\n'
                  'Hypertrophy: ${h.toStringAsFixed(isTonnage ? 1 : 0)}$suffix\n'
                  'Strength: ${s.toStringAsFixed(isTonnage ? 1 : 0)}$suffix\n'
                  'Max Effort: ${m.toStringAsFixed(isTonnage ? 1 : 0)}$suffix',
                  TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 11,
                    height: 1.5,
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

class _ZoneSummary extends StatelessWidget {
  const _ZoneSummary({required this.weeks});

  final List<VolumeZoneWeek> weeks;

  @override
  Widget build(BuildContext context) {
    // Aggregate across all non-deload weeks
    int totTechnique = 0;
    int totHypertrophy = 0;
    int totStrength = 0;
    int totMaxEffort = 0;

    for (final w in weeks) {
      if (w.isDeload) continue;
      totTechnique += w.techniqueSets;
      totHypertrophy += w.hypertrophySets;
      totStrength += w.strengthSets;
      totMaxEffort += w.maxEffortSets;
    }

    final total = totTechnique + totHypertrophy + totStrength + totMaxEffort;
    if (total == 0) return const SizedBox.shrink();

    final highPct = ((totStrength + totMaxEffort) / total * 100).round();
    final dominantCount = [totTechnique, totHypertrophy, totStrength, totMaxEffort].reduce(
      (a, b) => a > b ? a : b,
    );
    final dominantLabel = dominantCount == totTechnique
        ? 'technique'
        : dominantCount == totHypertrophy
            ? 'hypertrophy'
            : dominantCount == totStrength
                ? 'strength'
                : 'max-effort';

    return Text(
      '$highPct% of your sets are in the strength+ zone. '
      'Most volume is concentrated in $dominantLabel work.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Personal records list
// ---------------------------------------------------------------------------

// Issue #6: changed from ConsumerWidget to StatelessWidget — ref was never
// used inside build(); navigation uses BuildContext, not Riverpod.
class _PersonalRecordsList extends StatelessWidget {
  const _PersonalRecordsList({
    required this.records,
    this.athleteName,
  });

  final List<ProgressPersonalRecord> records;
  final String? athleteName;

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
          onShare: () => PrShareBottomSheet.show(
            context,
            PrCardData.fromProgressPr(pr, athleteName: athleteName),
          ),
        );
      }).toList(),
    );
  }
}

class _PersonalRecordTile extends StatelessWidget {
  const _PersonalRecordTile({
    required this.record,
    required this.onTap,
    this.onShare,
  });

  final ProgressPersonalRecord record;
  final VoidCallback onTap;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      onLongPress: onShare,
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatValue(record.recordType, record.value),
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onShare != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 18),
              tooltip: 'Share PR',
              onPressed: onShare,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
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
// Strength balance ratios card
// ---------------------------------------------------------------------------

// Expected S/B/D ratios relative to squat for raw powerlifting.
// Female bench is typically ~0.56× vs male 0.65×; deadlift stays at 1.1× for both.
const _kMaleRatios = (squat: 1.0, bench: 0.65, deadlift: 1.10);
const _kFemaleRatios = (squat: 1.0, bench: 0.56, deadlift: 1.10);

class _StrengthBalanceCard extends ConsumerStatefulWidget {
  const _StrengthBalanceCard();

  @override
  ConsumerState<_StrengthBalanceCard> createState() =>
      _StrengthBalanceCardState();
}

class _StrengthBalanceCardState extends ConsumerState<_StrengthBalanceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sbdAsync = ref.watch(sbdTotalProvider);
    final profile = ref.watch(profileStreamProvider).value;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return sbdAsync.when(
      // Don't render a skeleton for this card — SBD data is already loaded by
      // _SbdTotalCard above it, so the loading state is extremely brief.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (sbd) {
        // Need squat (the baseline) and at least one other lift to show ratios.
        if (sbd.liftCount < 2 || sbd.squat == null) return const SizedBox.shrink();

        final gender = profile?.gender;
        final ratios = gender == 'F' ? _kFemaleRatios : _kMaleRatios;
        final squat = sbd.squat;
        final bench = sbd.bench;
        final deadlift = sbd.deadlift;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tappable header row — expands/collapses the card body
                Semantics(
                  button: true,
                  label: 'Strength Balance, ${_expanded ? 'expanded' : 'collapsed'}',
                  child: InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Icon(Icons.balance, size: 20, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Strength Balance',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_expanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StrengthBalanceChart(
                          squat: squat,
                          bench: bench,
                          deadlift: deadlift,
                          ratios: ratios,
                        ),
                        const SizedBox(height: 16),
                        _StrengthInsights(
                          squat: squat,
                          bench: bench,
                          deadlift: deadlift,
                          ratios: ratios,
                          gender: gender,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StrengthBalanceChart extends StatelessWidget {
  const _StrengthBalanceChart({
    required this.squat,
    required this.bench,
    required this.deadlift,
    required this.ratios,
  });

  final double? squat;
  final double? bench;
  final double? deadlift;
  final ({double squat, double bench, double deadlift}) ratios;

  // Color encodes how close the lift is to its standard:
  // ≥95% of target → green, ≥85% → yellow, <85% → red.
  // Squat is always the baseline, so it's always at 100% of its own standard.
  Color _barColor(double actual, double target, ColorScheme cs) {
    if (target == 0) return cs.primary;
    final pct = actual / target;
    if (pct >= 0.95) return Colors.green;
    if (pct >= 0.85) return Colors.orange;
    return cs.error;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final squat = this.squat;
    // Chart can't render without the squat baseline.
    if (squat == null) return const SizedBox.shrink();

    final benchTarget = squat * ratios.bench;
    final deadliftTarget = squat * ratios.deadlift;

    // maxY = highest of all actuals and all targets, padded by 10%.
    final values = [
      squat, squat * ratios.squat,
      if (bench != null) ...[bench!, benchTarget],
      if (deadlift != null) ...[deadlift!, deadliftTarget],
    ];
    final maxY = values.reduce((a, b) => a > b ? a : b) * 1.15;

    BarChartRodData rod(double actual, double target, {bool showTarget = true}) {
      final color = _barColor(actual, target, cs);
      return BarChartRodData(
        toY: actual,
        color: color,
        width: 36,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        // Background rod shows the target as a grey cap above the actual bar
        // when the lift is below standard. Hidden when actual == target
        // (i.e. squat vs its own baseline) — nothing to show.
        backDrawRodData: BackgroundBarChartRodData(
          show: showTarget,
          toY: target,
          color: cs.surfaceContainerHighest,
        ),
      );
    }

    final groups = <BarChartGroupData>[
      // showTarget: false — squat is the baseline, actual always equals its own target.
      BarChartGroupData(x: 0, barRods: [rod(squat, squat * ratios.squat, showTarget: false)]),
      if (bench != null)
        BarChartGroupData(x: 1, barRods: [rod(bench!, benchTarget)]),
      if (deadlift != null)
        BarChartGroupData(x: 2, barRods: [rod(deadlift!, deadliftTarget)]),
    ];

    // Keyed by the fl_chart X coordinate — not a positional list — so axis
    // titles and tooltips are correct even when bench is absent (x: 2 for
    // deadlift would be out of range on a positional list of length 2).
    final xToLabel = <int, String>{
      0: 'Squat',
      if (bench != null) 1: 'Bench',
      if (deadlift != null) 2: 'Deadlift',
    };

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final label = xToLabel[value.toInt()];
                  if (label == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '${value.toInt()} kg',
                    style:
                        TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
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
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final liftName = xToLabel[group.x] ?? '';
                final target = switch (liftName) {
                  'Squat' => squat * ratios.squat,
                  'Bench' => squat * ratios.bench,
                  _ => squat * ratios.deadlift,
                };
                final pct = ((rod.toY / target) * 100).round();
                return BarTooltipItem(
                  '$liftName\n${rod.toY.toStringAsFixed(1)} kg ($pct% of target)',
                  TextStyle(color: cs.onPrimary, fontSize: 11),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StrengthInsights extends StatelessWidget {
  const _StrengthInsights({
    required this.squat,
    required this.bench,
    required this.deadlift,
    required this.ratios,
    required this.gender,
  });

  final double? squat;
  final double? bench;
  final double? deadlift;
  final ({double squat, double bench, double deadlift}) ratios;
  final String? gender;

  @override
  Widget build(BuildContext context) {
    final squat = this.squat;
    if (squat == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final insights = <Widget>[];

    void addInsight(String liftName, double? actual, double target) {
      if (actual == null) return;
      final gap = target - actual;
      final pct = ((actual / target) * 100).round();
      Color color;
      String msg;

      if (actual >= target * 0.95) {
        color = Colors.green;
        msg = 'Your $liftName (${actual.toStringAsFixed(1)} kg) is on target '
            '($pct% of the expected ${target.toStringAsFixed(1)} kg).';
      } else if (actual >= target * 0.85) {
        color = Colors.orange;
        msg = 'Your $liftName (${actual.toStringAsFixed(1)} kg) is $pct% of '
            'the expected ${target.toStringAsFixed(1)} kg — '
            '${gap.toStringAsFixed(1)} kg below standard.';
      } else {
        color = cs.error;
        msg = 'Your $liftName (${actual.toStringAsFixed(1)} kg) is $pct% of '
            'the expected ${target.toStringAsFixed(1)} kg — '
            '${gap.toStringAsFixed(1)} kg below standard. Consider prioritising $liftName work.';
      }

      insights.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(Icons.circle, size: 8, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final standardLabel = gender == 'F' ? 'female raw' : 'male raw';
    addInsight('bench', bench, squat * ratios.bench);
    addInsight('deadlift', deadlift, squat * ratios.deadlift);

    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights · $standardLabel standards',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...insights,
      ],
    );
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
