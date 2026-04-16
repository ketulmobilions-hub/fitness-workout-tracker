import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays a single logged set with a swipe-to-delete affordance.
class LoggedSetTile extends StatelessWidget {
  const LoggedSetTile({
    super.key,
    required this.set,
    required this.exerciseType,
    required this.onDelete,
  });

  final SetLog set;
  // Fix #12: exercise type drives the display format rather than relying on
  // which fields happen to be populated (field-presence heuristic).
  final ExerciseType exerciseType;
  // Fix #6: async callback so confirmDismiss can await the delete and keep
  // the tile visible on failure rather than silently disappearing.
  final Future<void> Function() onDelete;

  String _summary() {
    if (exerciseType != ExerciseType.strength) {
      // Cardio / stretching: distance · duration · pace · HR
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
      if (set.paceSecPerKm != null) {
        final paceMin = set.paceSecPerKm! ~/ 60;
        final paceSec = (set.paceSecPerKm! % 60).round();
        parts.add('$paceMin:${paceSec.toString().padLeft(2, '0')}/km');
      }
      if (set.heartRate != null) parts.add('HR ${set.heartRate}');
      if (set.rpe != null) parts.add('RPE ${set.rpe}');
      return parts.isEmpty ? '—' : parts.join('  ·  ');
    }

    // Strength: weight × reps, RPE, tempo
    final parts = <String>[];
    if (set.weightKg != null) {
      final w = set.weightKg!;
      parts.add(w == w.truncateToDouble() ? '${w.toInt()} kg' : '$w kg');
    }
    if (set.reps != null) parts.add('× ${set.reps}');
    if (set.rpe != null) parts.add('RPE ${set.rpe}');
    if (set.tempo != null && set.tempo!.isNotEmpty) parts.add(set.tempo!);
    if (parts.isEmpty && set.durationSec != null) parts.add('${set.durationSec}s');
    return parts.isEmpty ? '—' : parts.join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(set.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer),
      ),
      // Fix #6: await the async delete before confirming dismissal. If the
      // delete fails, return false so the tile snaps back and the user sees
      // an error — prevents "ghost sets" reappearing from a failed DB write.
      confirmDismiss: (_) async {
        // Capture messenger before the await to avoid using BuildContext
        // across an async gap (use_build_context_synchronously).
        final messenger = ScaffoldMessenger.of(context);
        try {
          await onDelete();
          return true;
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to delete set: $e'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
          return false;
        }
      },
      child: ListTile(
        dense: true,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '${set.setNumber}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(_summary(), style: theme.textTheme.bodyMedium),
        trailing: set.isWarmup
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Warm-up',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              )
            : const Icon(Icons.check_circle, color: Colors.green, size: 20),
      ),
    );
  }
}

/// Form for entering a new set. Calls [onLog] when the user taps the
/// checkmark. Pre-fills weight and reps from the last logged set for convenience.
class SetInputRow extends StatefulWidget {
  const SetInputRow({
    super.key,
    required this.setNumber,
    required this.onLog,
    this.previousWeight,
    this.previousReps,
    this.targetReps,
    this.targetSets,
  });

  final int setNumber;
  final void Function({
    int? reps,
    double? weightKg,
    int? rpe,
    String? tempo,
    bool isWarmup,
  }) onLog;
  final double? previousWeight;
  final int? previousReps;
  final String? targetReps;
  final int? targetSets;

  @override
  State<SetInputRow> createState() => _SetInputRowState();
}

class _SetInputRowState extends State<SetInputRow> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _repsCtrl;
  final TextEditingController _rpeCtrl = TextEditingController();
  final TextEditingController _tempoCtrl = TextEditingController();
  bool _isWarmup = false;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: widget.previousWeight != null
          ? (widget.previousWeight! == widget.previousWeight!.truncateToDouble()
              ? widget.previousWeight!.toInt().toString()
              : widget.previousWeight!.toString())
          : '',
    );
    _repsCtrl = TextEditingController(
      text: widget.previousReps?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _rpeCtrl.dispose();
    _tempoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final weightKg = double.tryParse(_weightCtrl.text.trim());
    final reps = int.tryParse(_repsCtrl.text.trim());
    final rpe = int.tryParse(_rpeCtrl.text.trim());
    final tempo = _tempoCtrl.text.trim();
    widget.onLog(
      reps: reps,
      weightKg: weightKg,
      rpe: rpe,
      tempo: tempo.isEmpty ? null : tempo,
      isWarmup: _isWarmup,
    );
    // Clear fields after logging.
    _rpeCtrl.clear();
    _tempoCtrl.clear();
    setState(() => _showAdvanced = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.setNumber}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    controller: _weightCtrl,
                    label: 'kg',
                    decimal: true,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('×'),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumberField(
                    controller: _repsCtrl,
                    label: 'reps',
                    decimal: false,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_showAdvanced) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _rpeCtrl,
                      label: 'RPE (1-10)',
                      decimal: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _tempoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tempo',
                        hintText: 'e.g. 3-1-2',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _isWarmup,
                    onChanged: (v) => setState(() => _isWarmup = v ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text('Warm-up set', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
            TextButton.icon(
              onPressed: () =>
                  setState(() => _showAdvanced = !_showAdvanced),
              icon: Icon(
                _showAdvanced
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 16,
              ),
              label:
                  Text(_showAdvanced ? 'Hide options' : 'RPE / Tempo / Warm-up'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.decimal,
  });

  final TextEditingController controller;
  final String label;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          TextInputType.numberWithOptions(decimal: decimal, signed: false),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      textAlign: TextAlign.center,
    );
  }
}
