import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';

/// Displays a single exercise with all its logged sets in the session detail
/// screen.
class SessionExerciseTile extends StatelessWidget {
  const SessionExerciseTile({super.key, required this.exerciseLog});

  final ExerciseLog exerciseLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Issue #15 fix: render sets in chronological (setNumber) order,
    // preserving the actual workout sequence. Warmup sets are visually
    // distinguished with a 'W' label but appear in their correct position.
    final sortedSets = [...exerciseLog.sets]
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exerciseLog.exerciseName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (exerciseLog.notes != null &&
                exerciseLog.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                exerciseLog.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (sortedSets.isEmpty)
              Text(
                'No sets logged',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...sortedSets.map((set) => _SetRow(set: set)),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set});

  final SetLog set;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _formatSet(set);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              set.isWarmup ? 'W' : '${set.setNumber}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: set.isWarmup
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSet(SetLog s) {
    final parts = <String>[];

    // Cardio fields take priority
    if (s.distanceM != null) {
      final km = s.distanceM! / 1000;
      parts.add('${km.toStringAsFixed(2)} km');
    }
    if (s.durationSec != null && s.distanceM != null) {
      parts.add(_formatDuration(s.durationSec!));
    }
    if (s.paceSecPerKm != null) {
      parts.add('${_formatDuration(s.paceSecPerKm!.round())}/km');
    }
    if (s.heartRate != null) {
      parts.add('HR ${s.heartRate}');
    }

    // Strength fields (only if no cardio distance)
    if (s.distanceM == null) {
      if (s.weightKg != null && s.reps != null) {
        final weight = s.weightKg! % 1 == 0
            ? '${s.weightKg!.toInt()} kg'
            : '${s.weightKg} kg';
        parts.add('$weight × ${s.reps}');
      } else if (s.reps != null) {
        parts.add('${s.reps} reps');
      } else if (s.durationSec != null) {
        parts.add(_formatDuration(s.durationSec!));
      }
    }

    if (s.rpe != null) parts.add('RPE ${s.rpe}');
    if (s.tempo != null) parts.add('tempo:${s.tempo}');

    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  // Issue #14 fix: handles durations longer than 59:59 (e.g. a 90-min run
  // shows as 1:30:00 not 90:00). Mirrors SessionHistoryCard._formatDuration.
  String _formatDuration(int totalSec) {
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
