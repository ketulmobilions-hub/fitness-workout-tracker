import 'package:fitness_domain/fitness_domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Wilks & Dots trend line chart across completed competitions (meet data only).
/// Callers should guard with per-series ≥2 checks before rendering.
class CompetitionScoreChart extends StatelessWidget {
  const CompetitionScoreChart({super.key, required this.meets});

  /// Completed meets sorted ascending by date.
  final List<Competition> meets;

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final scored =
        meets.where((m) => m.dots != null || m.wilks != null).toList();
    if (scored.length < 2) return const SizedBox.shrink();

    final dotsSpots = <FlSpot>[];
    final wilksSpots = <FlSpot>[];
    for (int i = 0; i < scored.length; i++) {
      final m = scored[i];
      if (m.dots != null) dotsSpots.add(FlSpot(i.toDouble(), m.dots!));
      if (m.wilks != null) wilksSpots.add(FlSpot(i.toDouble(), m.wilks!));
    }

    final allY = [
      ...dotsSpots.map((s) => s.y),
      ...wilksSpots.map((s) => s.y),
    ];
    final rawMin = allY.reduce((a, b) => a < b ? a : b);
    final rawMax = allY.reduce((a, b) => a > b ? a : b);
    // Guard against identical scores collapsing the Y range to zero.
    final rawPadding = (rawMax - rawMin) * 0.15;
    final padding = rawPadding < 10.0 ? 10.0 : rawPadding;
    final minY = (rawMin - padding).floorToDouble();
    final maxY = (rawMax + padding).ceilToDouble();

    // barLabels mirrors bars — same conditional guards — so tooltip lookup
    // barLabels[s.barIndex] is always correct regardless of which series exist.
    final barLabels = <String>[
      if (dotsSpots.length >= 2) 'Dots',
      if (wilksSpots.length >= 2) 'Wilks',
    ];
    final bars = <LineChartBarData>[
      if (dotsSpots.length >= 2)
        LineChartBarData(
          spots: dotsSpots,
          color: cs.primary,
          isCurved: dotsSpots.length > 2,
          barWidth: 2.5,
          dotData: FlDotData(
            getDotPainter: (_, _, _, _) => FlDotCirclePainter(
              radius: 4,
              color: cs.primary,
              strokeWidth: 0,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: cs.primary.withValues(alpha: 0.08),
          ),
        ),
      if (wilksSpots.length >= 2)
        LineChartBarData(
          spots: wilksSpots,
          color: cs.secondary,
          isCurved: wilksSpots.length > 2,
          barWidth: 2,
          dashArray: [5, 4],
          dotData: FlDotData(
            getDotPainter: (_, _, _, _) => FlDotCirclePainter(
              radius: 3,
              color: cs.secondary,
              strokeWidth: 0,
            ),
          ),
        ),
    ];

    final labelStyle = tt.labelSmall?.copyWith(color: cs.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Competition Scores',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          'Dots & Wilks across meets',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              lineBarsData: bars,
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(
                      v.toStringAsFixed(0),
                      style: labelStyle,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= scored.length) {
                        return const SizedBox.shrink();
                      }
                      final date = scored[idx].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "${_monthAbbr[date.month - 1]} '${(date.year % 100).toString().padLeft(2, '0')}",
                          style: labelStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => cs.surfaceContainerHigh,
                  getTooltipItems: (spots) => spots.map((s) {
                    final label = barLabels[s.barIndex];
                    return LineTooltipItem(
                      '$label ${s.y.toStringAsFixed(2)}',
                      tt.labelSmall?.copyWith(color: cs.onSurface) ??
                          const TextStyle(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (dotsSpots.length >= 2) ...[
              _LegendDot(color: cs.primary, label: 'Dots'),
              const SizedBox(width: 16),
            ],
            if (wilksSpots.length >= 2)
              _LegendDash(color: cs.secondary, label: 'Wilks'),
          ],
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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _LegendDash extends StatelessWidget {
  const _LegendDash({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          child: CustomPaint(
            painter: _DashPainter(color: color),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashWidth = 4.0;
    const gap = 3.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
