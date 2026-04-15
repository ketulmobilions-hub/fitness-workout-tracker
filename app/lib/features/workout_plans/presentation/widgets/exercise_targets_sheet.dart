import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/plan_form_provider.dart';
import '../../providers/plan_form_state.dart';

/// Shows a modal bottom sheet for editing the target fields of a single
/// [DraftPlanExercise] inside the plan form.
///
/// The exercise is identified by [exercise.localId] so the sheet always edits
/// the correct entry even if a reorder happened after the sheet was opened.
Future<void> showExerciseTargetsSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String? planId,
  required DraftPlanExercise exercise,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ExerciseTargetsSheet(
      planId: planId,
      exercise: exercise,
    ),
  );
}

class _ExerciseTargetsSheet extends ConsumerStatefulWidget {
  const _ExerciseTargetsSheet({
    required this.planId,
    required this.exercise,
  });

  final String? planId;
  final DraftPlanExercise exercise;

  @override
  ConsumerState<_ExerciseTargetsSheet> createState() =>
      _ExerciseTargetsSheetState();
}

class _ExerciseTargetsSheetState
    extends ConsumerState<_ExerciseTargetsSheet> {
  late TextEditingController _setsCtrl;
  late TextEditingController _repsCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _distanceCtrl;
  late TextEditingController _notesCtrl;

  /// Validation errors keyed by field name. Shown inline below each field.
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final ex = widget.exercise;
    _setsCtrl =
        TextEditingController(text: ex.targetSets?.toString() ?? '');
    _repsCtrl = TextEditingController(text: ex.targetReps ?? '');
    _durationCtrl = TextEditingController(
      text: ex.targetDurationSec != null
          ? _secsToMmSs(ex.targetDurationSec!)
          : '',
    );
    _distanceCtrl = TextEditingController(
      text: ex.targetDistanceM != null
          ? (ex.targetDistanceM! / 1000).toStringAsFixed(2)
          : '',
    );
    _notesCtrl = TextEditingController(text: ex.notes ?? '');
  }

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _durationCtrl.dispose();
    _distanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.exercise.exerciseType;
    final insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.exercise.exerciseName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // Strength: sets + reps
          if (type == ExerciseType.strength) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Sets',
                      border: const OutlineInputBorder(),
                      errorText: _errors['sets'],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _repsCtrl,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'Reps (e.g. 8-12)',
                      border: const OutlineInputBorder(),
                      errorText: _errors['reps'],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Cardio: duration + distance
          if (type == ExerciseType.cardio) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'Duration (mm:ss)',
                      border: const OutlineInputBorder(),
                      errorText: _errors['duration'],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _distanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Distance (km)',
                      border: const OutlineInputBorder(),
                      errorText: _errors['distance'],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Stretching: sets + duration
          if (type == ExerciseType.stretching) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Sets',
                      border: const OutlineInputBorder(),
                      errorText: _errors['sets'],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'Duration (mm:ss)',
                      border: const OutlineInputBorder(),
                      errorText: _errors['duration'],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Notes (any type)
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          FilledButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  bool _validate() {
    final newErrors = <String, String>{};

    // Sets: must be a positive integer between 1 and 100 if provided.
    final setsText = _setsCtrl.text.trim();
    if (setsText.isNotEmpty) {
      final sets = int.tryParse(setsText);
      if (sets == null || sets < 1 || sets > 100) {
        newErrors['sets'] = '1–100';
      }
    }

    // Reps: must match digit or range format if provided.
    final repsText = _repsCtrl.text.trim();
    if (repsText.isNotEmpty) {
      final repsPattern = RegExp(r'^\d+(-\d+)?$');
      if (!repsPattern.hasMatch(repsText)) {
        newErrors['reps'] = 'Use a number or range (e.g. 10 or 8-12)';
      }
    }

    // Duration: mm:ss format or plain seconds if provided.
    final durationText = _durationCtrl.text.trim();
    if (durationText.isNotEmpty) {
      final secs = _mmSsToSecs(durationText);
      if (secs == null || secs < 1) {
        newErrors['duration'] = 'Enter a valid duration (mm:ss)';
      }
    }

    // Distance: positive number if provided.
    final distanceText = _distanceCtrl.text.trim();
    if (distanceText.isNotEmpty) {
      final km = double.tryParse(distanceText);
      if (km == null || km <= 0) {
        newErrors['distance'] = 'Must be > 0';
      }
    }

    setState(() => _errors
      ..clear()
      ..addAll(newErrors));
    return newErrors.isEmpty;
  }

  void _save() {
    if (!_validate()) return;

    final type = widget.exercise.exerciseType;
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    // Only parse and clear fields that are visible for this exercise type.
    // Fields that are NOT shown must never be cleared — they keep their
    // existing value regardless of what the hidden controllers contain.
    final int? sets = (type == ExerciseType.strength || type == ExerciseType.stretching)
        ? int.tryParse(_setsCtrl.text.trim())
        : null;
    final bool clearSets = (type == ExerciseType.strength || type == ExerciseType.stretching)
        && sets == null;

    final String? reps = (type == ExerciseType.strength)
        ? (_repsCtrl.text.trim().isEmpty ? null : _repsCtrl.text.trim())
        : null;
    final bool clearReps = type == ExerciseType.strength && reps == null;

    final int? durationSec = (type == ExerciseType.cardio || type == ExerciseType.stretching)
        ? _mmSsToSecs(_durationCtrl.text.trim())
        : null;
    final bool clearDuration = (type == ExerciseType.cardio || type == ExerciseType.stretching)
        && durationSec == null;

    final double? distanceM = (type == ExerciseType.cardio)
        ? (double.tryParse(_distanceCtrl.text.trim()) != null
            ? double.parse(_distanceCtrl.text.trim()) * 1000
            : null)
        : null;
    final bool clearDistance = type == ExerciseType.cardio && distanceM == null;

    ref.read(planFormProvider(widget.planId).notifier).updateExerciseTargets(
          localId: widget.exercise.localId,
          targetSets: sets,
          clearSets: clearSets,
          targetReps: reps,
          clearReps: clearReps,
          targetDurationSec: durationSec,
          clearDuration: clearDuration,
          targetDistanceM: distanceM,
          clearDistance: clearDistance,
          notes: notes,
          clearNotes: notes == null,
        );

    Navigator.of(context).pop();
  }

  String _secsToMmSs(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int? _mmSsToSecs(String input) {
    if (input.isEmpty) return null;
    final parts = input.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final s = int.tryParse(parts[1]);
      if (m != null && s != null) return m * 60 + s;
    }
    return int.tryParse(input);
  }
}
