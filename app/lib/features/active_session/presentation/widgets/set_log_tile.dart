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
    this.previousTempo,
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
  /// Tempo from the most recent set in the current session — auto-filled.
  final String? previousTempo;
  final String? targetReps;
  final int? targetSets;

  @override
  State<SetInputRow> createState() => _SetInputRowState();
}

class _SetInputRowState extends State<SetInputRow> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _repsCtrl;
  double? _selectedRpe;
  bool _isWarmup = false;
  bool _showAdvanced = false;
  /// Incremented after submit to force _TempoInput to recreate with fresh state.
  int _tempoResetKey = 0;
  /// Driven exclusively by _TempoInput.onChanged — null when section is hidden.
  /// Never seeded from widget.previousTempo directly; _TempoInput handles that
  /// via its initialValue so the value is only active when visible to the user.
  String? _currentTempo;

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
    // _currentTempo intentionally NOT seeded from widget.previousTempo here.
    // _TempoInput calls onChanged immediately on mount (initState → _notify),
    // so _currentTempo is set only when the advanced section is open and the
    // user has seen the field — preventing silent phantom tempo on hidden sets.
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final weightKg = double.tryParse(_weightCtrl.text.trim());
    final reps = int.tryParse(_repsCtrl.text.trim());
    widget.onLog(
      reps: reps,
      weightKg: weightKg,
      rpe: _selectedRpe,
      tempo: _currentTempo,
      isWarmup: _isWarmup,
    );
    setState(() {
      _selectedRpe = null;
      _showAdvanced = false;
      _isWarmup = false;
      _currentTempo = null; // cleared; _TempoInput re-seeds via onChanged on next open
      _tempoResetKey++;
    });
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
              _TempoInput(
                key: ValueKey(_tempoResetKey),
                initialValue: widget.previousTempo,
                onChanged: (v) => _currentTempo = v,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
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

// ── Tempo presets ─────────────────────────────────────────────────────────────

const _tempoPresets = [
  ('Touch & Go', '1-0-X-0'),
  ('Controlled', '3-1-2-0'),
  ('Pause', '3-2-X-0'),
  ('Slow Ecc.', '4-1-X-0'),
];

/// 4-segment tempo input (eccentric–bottom pause–concentric–top pause).
/// Each segment accepts a single digit (0–9) or the letter X.
/// Auto-advances focus to the next segment after a valid character is entered.
/// Preset buttons fill all four segments at once.
class _TempoInput extends StatefulWidget {
  const _TempoInput({super.key, this.initialValue, required this.onChanged});

  final String? initialValue;
  final void Function(String?) onChanged;

  @override
  State<_TempoInput> createState() => _TempoInputState();
}

class _TempoInputState extends State<_TempoInput> {
  final _ctrls = List.generate(4, (_) => TextEditingController());
  final _nodes = List.generate(4, (_) => FocusNode());

  static const _labels = ['Ecc', 'Bot', 'Con', 'Top'];

  @override
  void initState() {
    super.initState();
    // Attach backspace-backward listeners before filling values.
    for (var i = 1; i < 4; i++) {
      final idx = i;
      _nodes[idx].onKeyEvent = (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _ctrls[idx].text.isEmpty) {
          _nodes[idx - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
    _applyValue(widget.initialValue);
    // Notify parent with the pre-filled value so _currentTempo is in sync
    // from the moment _TempoInput is mounted, not only after the user types.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notify();
    });
  }

  @override
  void didUpdateWidget(_TempoInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handles the case where parent rebuilds (e.g. set deleted) with a new
    // initialValue without triggering a key-forced full recreation.
    if (oldWidget.initialValue != widget.initialValue) {
      _applyValue(widget.initialValue);
      _notify();
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  /// Fills controllers from [tempo]. Validates each segment: takes only the
  /// first valid char (0–9 or X, uppercased) to guard against malformed DB
  /// values bypassing the max-1-char formatter.
  void _applyValue(String? tempo) {
    if (tempo == null) {
      for (final c in _ctrls) c.text = '';
      return;
    }
    final segs = tempo.split('-');
    if (segs.length != 4) {
      for (final c in _ctrls) c.text = '';
      return;
    }
    for (var i = 0; i < 4; i++) {
      final cleaned = segs[i]
          .toUpperCase()
          .replaceAll(RegExp(r'[^0-9X]'), '');
      _ctrls[i].text = cleaned.isNotEmpty ? cleaned[0] : '';
    }
  }

  void _onSegmentChanged(int index, String val) {
    final cleaned = val.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');
    if (cleaned != val) {
      _ctrls[index].value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }
    if (cleaned.isNotEmpty && index < 3) {
      _nodes[index + 1].requestFocus();
    }
    _notify();
  }

  void _notify() {
    final segs = _ctrls.map((c) => c.text.toUpperCase()).toList();
    final complete = segs.every((s) => s.isNotEmpty);
    widget.onChanged(complete ? segs.join('-') : null);
  }

  void _applyPreset(String tempo) {
    _applyValue(tempo);
    _notify();
    // Dismiss keyboard and clear focus from all segment boxes.
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tempo (ecc – bot – con – top)',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        // ── 4 segment boxes ──────────────────────────────────────────────────
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
                child: Column(
                  children: [
                    TextField(
                      controller: _ctrls[i],
                      focusNode: _nodes[i],
                      textCapitalization: TextCapitalization.characters,
                      keyboardType: TextInputType.text,
                      maxLength: 1,
                      textAlign: TextAlign.center,
                      onChanged: (v) => _onSegmentChanged(i, v),
                      decoration: InputDecoration(
                        counterText: '',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        hintText: i == 1 || i == 3 ? '0' : 'X',
                        hintStyle: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant
                              .withAlpha(100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _labels[i],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        // ── Preset chips ─────────────────────────────────────────────────────
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: _tempoPresets.map((p) {
            final (label, value) = p;
            return ActionChip(
              label: Text(label),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              labelStyle: theme.textTheme.labelSmall,
              onPressed: () => _applyPreset(value),
            );
          }).toList(),
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
