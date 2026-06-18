import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

class CompetitionCard extends StatelessWidget {
  const CompetitionCard({super.key, required this.comp, this.onTap});

  final Competition comp;
  final VoidCallback? onTap;

  static int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isUpcoming = comp.status == CompetitionStatus.upcoming;

    final meta = [
      formatDate(comp.date),
      if (comp.federation != null) comp.federation!,
      if (comp.location != null) comp.location!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comp.name,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isUpcoming)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Upcoming',
                        style: tt.labelSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                meta,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),

              // Upcoming: countdown
              if (isUpcoming) ...[
                const SizedBox(height: 8),
                _Countdown(date: comp.date, daysUntil: _daysUntil(comp.date)),
              ],

              // Completed: total + scores + S/B/D
              if (!isUpcoming && comp.total != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${comp.total!.toStringAsFixed(1)} kg',
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    if (comp.dots != null) ...[
                      const SizedBox(width: 8),
                      _ScoreTag(label: 'Dots', value: comp.dots!, cs: cs, tt: tt),
                    ],
                    if (comp.wilks != null) ...[
                      const SizedBox(width: 8),
                      _ScoreTag(label: 'Wilks', value: comp.wilks!, cs: cs, tt: tt),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'S: ${comp.squat?.toStringAsFixed(1) ?? '—'}  '
                  'B: ${comp.bench?.toStringAsFixed(1) ?? '—'}  '
                  'D: ${comp.deadlift?.toStringAsFixed(1) ?? '—'}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],

              if (!isUpcoming && comp.total == null) ...[
                const SizedBox(height: 4),
                Text(
                  'No lifts recorded',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.date, required this.daysUntil});
  final DateTime date;
  final int daysUntil;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final String label;
    if (daysUntil <= 0) {
      label = 'Today!';
    } else if (daysUntil == 1) {
      label = 'Tomorrow';
    } else {
      label = 'In $daysUntil days';
    }

    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 14, color: cs.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: tt.labelMedium?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ScoreTag extends StatelessWidget {
  const _ScoreTag({
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
  });

  final String label;
  final double value;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(2)}',
        style: tt.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
