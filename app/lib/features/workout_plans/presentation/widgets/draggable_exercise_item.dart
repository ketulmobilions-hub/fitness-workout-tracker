import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/plan_form_state.dart';
import 'exercise_targets_sheet.dart';
import 'exercise_type_icon.dart';

/// A single draggable exercise row used inside the plan form's exercise editor.
class DraggableExerciseItem extends ConsumerWidget {
  const DraggableExerciseItem({
    super.key,
    required this.planId,
    required this.dayIndex,
    required this.exerciseIndex,
    required this.exercise,
    required this.onRemove,
  });

  final String? planId;
  final int dayIndex;
  final int exerciseIndex;
  final DraftPlanExercise exercise;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = _targetSummary(exercise);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: ExerciseTypeIcon(type: exercise.exerciseType),
        title: Text(
          exercise.exerciseName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: summary.isNotEmpty
            ? Text(
                summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit targets',
              // Pass the exercise (with its stable localId) — not the mutable
              // exerciseIndex — so the sheet edits the right entry even if
              // reordering happened after this widget was built.
              onPressed: () => showExerciseTargetsSheet(
                context: context,
                ref: ref,
                planId: planId,
                exercise: exercise,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Remove exercise',
              onPressed: onRemove,
            ),
            // Drag handle — must wrap with ReorderableDragStartListener.
            ReorderableDragStartListener(
              index: exerciseIndex,
              child: const Icon(Icons.drag_handle),
            ),
          ],
        ),
      ),
    );
  }

  String _targetSummary(DraftPlanExercise ex) {
    if (ex.targetSets != null && ex.targetReps != null) {
      return '${ex.targetSets} × ${ex.targetReps}';
    }
    if (ex.targetSets != null) {
      return '${ex.targetSets} sets';
    }
    if (ex.targetDurationSec != null) {
      final mins = ex.targetDurationSec! ~/ 60;
      final secs = ex.targetDurationSec! % 60;
      if (mins > 0 && secs > 0) return '${mins}m ${secs}s';
      if (mins > 0) return '$mins min';
      return '${secs}s';
    }
    if (ex.targetDistanceM != null) {
      return '${(ex.targetDistanceM! / 1000).toStringAsFixed(1)} km';
    }
    return '';
  }
}
