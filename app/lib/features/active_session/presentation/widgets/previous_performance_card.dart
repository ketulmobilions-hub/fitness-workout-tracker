import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

import 'set_log_tile.dart';

/// Displays set logs from the user's last 3 sessions for the current exercise.
/// Each session shows all sets (warm-ups greyed), the top working set with RPE
/// badge, % change vs. the previous session, and tempo. A compact RPE-history
/// row at the bottom shows the best set per RPE value across all sessions.
class PreviousPerformanceCard extends StatelessWidget {
  const PreviousPerformanceCard({
    super.key,
    required this.previousSessions,
    required this.exerciseType,
  });

  final List<PreviousSessionData> previousSessions;
  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context) {
    if (previousSessions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(Icons.history,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Previous performance',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Session rows with dividers between them
          for (var i = 0; i < previousSessions.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: theme.colorScheme.outlineVariant,
              ),
            _SessionSection(
              session: previousSessions[i],
              nextSession: i + 1 < previousSessions.length
                  ? previousSessions[i + 1]
                  : null,
              exerciseType: exerciseType,
            ),
          ],

          // RPE history insight (strength only)
          _RpeHistoryRow(
            sessions: previousSessions,
            exerciseType: exerciseType,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session section
// ---------------------------------------------------------------------------

class _SessionSection extends StatelessWidget {
  const _SessionSection({
    required this.session,
    required this.nextSession,
    required this.exerciseType,
  });

  final PreviousSessionData session;
  final PreviousSessionData? nextSession;
  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topSet = session.topWorkingSet;
    final previousTopSet = nextSession?.topWorkingSet;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session header: date + % change
          Row(
            children: [
              Text(
                _formatDate(session.sessionDate),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (topSet != null && previousTopSet != null)
                _PercentChangeBadge(
                  current: topSet,
                  previous: previousTopSet,
                ),
            ],
          ),
          const SizedBox(height: 4),

          if (session.sets.isEmpty)
            Text(
              'No sets recorded',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Column(
              children: session.sets
                  .map((s) => _HistorySetRow(
                        set: s,
                        exerciseType: exerciseType,
                        isTop: topSet != null && s.id == topSet.id,
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual set row in history
// ---------------------------------------------------------------------------

class _HistorySetRow extends StatelessWidget {
  const _HistorySetRow({
    required this.set,
    required this.exerciseType,
    required this.isTop,
  });

  final SetLog set;
  final ExerciseType exerciseType;
  final bool isTop;

  String _setLabel() {
    if (exerciseType != ExerciseType.strength) {
      final parts = <String>[];
      if (set.distanceM != null) {
        final km = set.distanceM! / 1000;
        parts.add('${km.toStringAsFixed(2)} km');
      }
      if (set.durationSec != null) {
        final mins = set.durationSec! ~/ 60;
        final secs = set.durationSec! % 60;
        parts.add('$mins:${secs.toString().padLeft(2, '0')}');
      }
      return parts.isEmpty ? 'Set ${set.setNumber}' : parts.join(' · ');
    }

    final parts = <String>[];
    if (set.weightKg != null) {
      final w = set.weightKg!;
      parts.add(w == w.truncateToDouble() ? '${w.toInt()} kg' : '$w kg');
    }
    if (set.reps != null) parts.add('× ${set.reps}');
    return parts.isEmpty ? 'Set ${set.setNumber}' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWarmup = set.isWarmup;
    final textColor = isWarmup
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Set number
          SizedBox(
            width: 20,
            child: Text(
              '${set.setNumber}.',
              style: theme.textTheme.bodySmall?.copyWith(color: textColor),
            ),
          ),

          // Label (weight × reps or distance · duration)
          Expanded(
            child: Text(
              _setLabel(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: isTop && !isWarmup
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),

          // Tempo
          if (set.tempo != null) ...[
            const SizedBox(width: 4),
            Text(
              set.tempo!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: isWarmup ? 0.4 : 0.7),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],

          // RPE badge
          if (set.rpe != null) ...[
            const SizedBox(width: 4),
            Opacity(
              opacity: isWarmup ? 0.5 : 1.0,
              child: RpeBadge(rpe: set.rpe!),
            ),
          ],

          // Warmup indicator
          if (isWarmup) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'W',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// % change badge
// ---------------------------------------------------------------------------

class _PercentChangeBadge extends StatelessWidget {
  const _PercentChangeBadge({required this.current, required this.previous});

  final SetLog current;
  final SetLog previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentWeight = current.weightKg;
    final previousWeight = previous.weightKg;

    if (currentWeight == null || previousWeight == null || previousWeight == 0) {
      return const SizedBox.shrink();
    }

    final pct = ((currentWeight - previousWeight) / previousWeight) * 100;
    final isPositive = pct >= 0;
    final label =
        '${isPositive ? '+' : ''}${pct.toStringAsFixed(1)}%';
    final color =
        isPositive ? Colors.green.shade700 : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RPE history insight row
// ---------------------------------------------------------------------------

class _RpeHistoryRow extends StatelessWidget {
  const _RpeHistoryRow({
    required this.sessions,
    required this.exerciseType,
  });

  final List<PreviousSessionData> sessions;
  final ExerciseType exerciseType;

  @override
  Widget build(BuildContext context) {
    if (exerciseType != ExerciseType.strength) return const SizedBox.shrink();

    // Best working set per RPE across all sessions; newest session wins on ties.
    final bestByRpe = <double, SetLog>{};
    for (final session in sessions) {
      for (final set in session.sets) {
        if (set.rpe == null || set.isWarmup) continue;
        final existing = bestByRpe[set.rpe!];
        if (existing == null ||
            (set.weightKg ?? 0) > (existing.weightKg ?? 0)) {
          bestByRpe[set.rpe!] = set;
        }
      }
    }

    if (bestByRpe.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final sorted = bestByRpe.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1,
          indent: 12,
          endIndent: 12,
          color: theme.colorScheme.outlineVariant,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: sorted.map((entry) {
              final rpe = entry.key;
              final set = entry.value;
              final w = set.weightKg;
              final r = set.reps;
              final label = [
                if (w != null)
                  w == w.truncateToDouble() ? '${w.toInt()} kg' : '$w kg',
                if (r != null) '× $r',
              ].join(' ');

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RpeBadge(rpe: rpe),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final weekday = weekdays[date.weekday - 1];
  final month = months[date.month - 1];
  return '$weekday, $month ${date.day}';
}
