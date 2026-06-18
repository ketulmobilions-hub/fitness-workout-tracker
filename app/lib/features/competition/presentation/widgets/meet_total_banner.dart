import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

/// Sticky bottom banner showing running total, best lifts, and Wilks/Dots.
class MeetTotalBanner extends StatelessWidget {
  const MeetTotalBanner({super.key, required this.comp});

  final Competition comp;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Best lifts row
          Row(
            children: [
              _LiftChip(label: 'S', value: comp.squat),
              const SizedBox(width: 8),
              _LiftChip(label: 'B', value: comp.bench),
              const SizedBox(width: 8),
              _LiftChip(label: 'D', value: comp.deadlift),
              const Spacer(),
              if (comp.total != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${comp.total!.toStringAsFixed(1)} kg',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Total: —',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          // Score row
          if (comp.dots != null || comp.wilks != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (comp.dots != null)
                  _ScoreChip(label: 'Dots', value: comp.dots!),
                if (comp.dots != null && comp.wilks != null)
                  const SizedBox(width: 8),
                if (comp.wilks != null)
                  _ScoreChip(label: 'Wilks', value: comp.wilks!),
                if (comp.ipfGl != null) ...[
                  const SizedBox(width: 8),
                  _ScoreChip(label: 'IPF GL', value: comp.ipfGl!),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LiftChip extends StatelessWidget {
  const _LiftChip({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          value != null ? '${value!.toStringAsFixed(1)}' : '—',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: value != null ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
