import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef AttemptSaveCallback = Future<void> Function(
  double weightKg,
  String result,
);

/// Read-only visual display of a single attempt's result.
/// Shared between [AttemptCell] (animated, tappable) and the
/// read-only competition detail screen.
class AttemptResultDisplay extends StatelessWidget {
  const AttemptResultDisplay({
    super.key,
    required this.attempt,
    this.height = 60,
    this.animated = false,
  });

  final CompetitionAttempt? attempt;
  final double height;

  /// When true, wraps in [AnimatedContainer] so result color changes animate.
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Color borderColor;
    Color bgColor;
    Widget content;

    if (attempt == null || attempt!.result == AttemptResult.notTaken) {
      borderColor = cs.outlineVariant;
      bgColor = cs.surfaceContainerHighest;
      content = Text(
        attempt != null ? '${attempt!.weightKg.toStringAsFixed(1)} kg' : '—',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        textAlign: TextAlign.center,
      );
    } else if (attempt!.result == AttemptResult.goodLift) {
      borderColor = Colors.green.shade400;
      bgColor = Colors.green.withValues(alpha: 0.12);
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            attempt!.weightKg.toStringAsFixed(1),
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.green.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
        ],
      );
    } else {
      // no_lift
      borderColor = cs.error;
      bgColor = cs.errorContainer.withValues(alpha: 0.4);
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            attempt!.weightKg.toStringAsFixed(1),
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.error,
            ),
            textAlign: TextAlign.center,
          ),
          Icon(Icons.cancel, size: 14, color: cs.error),
        ],
      );
    }

    final decoration = BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: borderColor, width: 1.5),
    );

    if (animated) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        decoration: decoration,
        child: Center(child: content),
      );
    }
    return Container(
      height: height,
      decoration: decoration,
      child: Center(child: content),
    );
  }
}

/// Displays a single attempt cell in the meet day grid.
/// Tapping opens a bottom sheet to enter weight and record result.
class AttemptCell extends StatelessWidget {
  const AttemptCell({
    super.key,
    required this.competition,
    required this.liftType,
    required this.attemptNumber,
    required this.onSaved,
  });

  final Competition competition;
  final LiftType liftType;
  final int attemptNumber;
  final AttemptSaveCallback onSaved;

  CompetitionAttempt? get _attempt => competition.attempts
      .where(
        (a) => a.liftType == liftType && a.attemptNumber == attemptNumber,
      )
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    return GestureDetector(
      onTap: () => _showEntrySheet(context, attempt),
      child: AttemptResultDisplay(attempt: attempt, animated: true),
    );
  }

  void _showEntrySheet(BuildContext context, CompetitionAttempt? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AttemptEntrySheet(
        existing: existing,
        liftLabel: liftType.name[0].toUpperCase() + liftType.name.substring(1),
        attemptNumber: attemptNumber,
        onSaved: onSaved,
      ),
    );
  }
}

class _AttemptEntrySheet extends StatefulWidget {
  const _AttemptEntrySheet({
    required this.existing,
    required this.liftLabel,
    required this.attemptNumber,
    required this.onSaved,
  });

  final CompetitionAttempt? existing;
  final String liftLabel;
  final int attemptNumber;
  final AttemptSaveCallback onSaved;

  @override
  State<_AttemptEntrySheet> createState() => _AttemptEntrySheetState();
}

class _AttemptEntrySheetState extends State<_AttemptEntrySheet> {
  late final TextEditingController _weightCtrl;
  String _result = 'not_taken';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _weightCtrl = TextEditingController(
      text: existing != null ? existing.weightKg.toString() : '',
    );
    if (existing != null) {
      _result = switch (existing.result) {
        AttemptResult.goodLift => 'good_lift',
        AttemptResult.noLift => 'no_lift',
        AttemptResult.notTaken => 'not_taken',
      };
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(String result) async {
    final weight = double.tryParse(_weightCtrl.text.trim());
    if (weight == null || weight <= 0) return;
    setState(() {
      _saving = true;
      _result = result;
    });
    await widget.onSaved(weight, result);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ordinal = switch (widget.attemptNumber) {
      1 => '1st',
      2 => '2nd',
      3 => '3rd',
      final n => '${n}th',
    };
    // When editing an existing attempt, dim buttons that are not currently selected
    // so the coach can see at a glance which result is stored.
    final isExisting = widget.existing != null;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.liftLabel} — $ordinal Attempt',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              border: OutlineInputBorder(),
              suffixText: 'kg',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save('good_lift'),
                  icon: const Icon(Icons.check),
                  label: const Text('Good Lift'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isExisting && _result != 'good_lift'
                        ? Colors.green.shade600.withValues(alpha: 0.35)
                        : Colors.green.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save('no_lift'),
                  icon: const Icon(Icons.close),
                  label: const Text('No Lift'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isExisting && _result != 'no_lift'
                        ? colorScheme.error.withValues(alpha: 0.35)
                        : colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : () => _save('not_taken'),
            style: isExisting && _result != 'not_taken'
                ? TextButton.styleFrom(
                    foregroundColor:
                        colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  )
                : null,
            child: const Text('Mark as Not Taken'),
          ),
        ],
      ),
    );
  }
}
