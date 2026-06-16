import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// RPE values available in the quick-select picker (6–10, 0.5 steps).
const _rpeValues = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];

Color _rpeBadgeColor(double rpe) {
  if (rpe >= 10) return Colors.red.shade700;
  if (rpe >= 9) return Colors.orange.shade700;
  if (rpe >= 8) return Colors.amber.shade700;
  return Colors.green.shade700;
}

String _formatRpe(double rpe) =>
    rpe == rpe.truncateToDouble() ? rpe.toInt().toString() : rpe.toString();

/// Colored "@RPE" badge used on completed set tiles and history rows.
class RpeBadge extends StatelessWidget {
  const RpeBadge({super.key, required this.rpe});

  final double rpe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _rpeBadgeColor(rpe),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '@${_formatRpe(rpe)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// Displays a single logged set with a swipe-to-delete affordance.
class LoggedSetTile extends StatelessWidget {
  const LoggedSetTile({
    super.key,
    required this.set,
    required this.exerciseType,
    required this.onDelete,
  });

  final SetLog set;
  final ExerciseType exerciseType;
  final Future<void> Function() onDelete;

  String _summary() {
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
      if (set.paceSecPerKm != null) {
        final paceMin = set.paceSecPerKm! ~/ 60;
        final paceSec = (set.paceSecPerKm! % 60).round();
        parts.add('$paceMin:${paceSec.toString().padLeft(2, '0')}/km');
      }
      if (set.heartRate != null) parts.add('HR ${set.heartRate}');
      return parts.isEmpty ? '—' : parts.join('  ·  ');
    }

    // Strength: weight × reps (RPE shown as badge separately)
    final parts = <String>[];
    if (set.weightKg != null) {
      final w = set.weightKg!;
      parts.add(w == w.truncateToDouble() ? '${w.toInt()} kg' : '$w kg');
    }
    if (set.reps != null) parts.add('× ${set.reps}');
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
      confirmDismiss: (_) async {
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (set.rpe != null) ...[
              RpeBadge(rpe: set.rpe!),
              const SizedBox(width: 6),
            ],
            if (set.isWarmup)
              Container(
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
            else
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Form for entering a new set. RPE is a first-class quick-select picker
/// (6–10, 0.5 steps). Calls [onLog] when the user taps the checkmark.
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
    double? rpe,
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
  final TextEditingController _tempoCtrl = TextEditingController();
  double? _selectedRpe;
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
    _tempoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final weightKg = double.tryParse(_weightCtrl.text.trim());
    final reps = int.tryParse(_repsCtrl.text.trim());
    final tempo = _tempoCtrl.text.trim();
    widget.onLog(
      reps: reps,
      weightKg: weightKg,
      rpe: _selectedRpe,
      tempo: tempo.isEmpty ? null : tempo,
      isWarmup: _isWarmup,
    );
    setState(() {
      _selectedRpe = null;
      _showAdvanced = false;
      _isWarmup = false;
    });
    _tempoCtrl.clear();
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
            // ── Weight × reps row ───────────────────────────────────────────
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
            // ── RPE quick-select ─────────────────────────────────────────────
            const SizedBox(height: 10),
            RpeQuickSelect(
              selected: _selectedRpe,
              onSelect: (v) => setState(() => _selectedRpe = v),
            ),
            // ── Advanced: tempo + warm-up ────────────────────────────────────
            if (_showAdvanced) ...[
              const SizedBox(height: 8),
              Row(
                children: [
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
                  const SizedBox(width: 12),
                  Checkbox(
                    value: _isWarmup,
                    onChanged: (v) => setState(() => _isWarmup = v ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text('Warm-up', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
            TextButton.icon(
              onPressed: () =>
                  setState(() => _showAdvanced = !_showAdvanced),
              icon: Icon(
                _showAdvanced ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
              label: Text(_showAdvanced ? 'Hide options' : 'Tempo / Warm-up'),
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

/// Horizontal RPE quick-select strip (6–10, 0.5 steps).
/// Public so it can be reused in other input forms (e.g. cardio).
class RpeQuickSelect extends StatelessWidget {
  const RpeQuickSelect({super.key, required this.selected, required this.onSelect});

  final double? selected;
  final void Function(double?) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RPE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _rpeValues.map((v) {
              final isSelected = selected == v;
              final color = _rpeBadgeColor(v);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onSelect(isSelected ? null : v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : color.withAlpha(80),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '@${_formatRpe(v)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSelected ? Colors.white : color,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Allows digits and at most one decimal point.
class _SingleDotFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue value) {
    final text = value.text;
    if (text.isEmpty) return value;
    // Strip anything that isn't a digit or dot.
    final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
    // Keep only the first dot.
    final firstDot = cleaned.indexOf('.');
    final sanitised = firstDot == -1
        ? cleaned
        : cleaned.substring(0, firstDot + 1) +
            cleaned.substring(firstDot + 1).replaceAll('.', '');
    if (sanitised == text) return value;
    return value.copyWith(
      text: sanitised,
      selection: TextSelection.collapsed(offset: sanitised.length),
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
        if (decimal)
          _SingleDotFormatter()
        else
          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
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
