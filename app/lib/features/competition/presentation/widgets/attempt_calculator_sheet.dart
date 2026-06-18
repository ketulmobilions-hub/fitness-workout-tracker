import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../progress/providers/progress_providers.dart';
import '../../providers/competition_providers.dart';

enum _Confidence { conservative, standard, aggressive }

/// Attempt calculator bottom sheet.
///
/// Pre-fills training maxes from the user's all-time SBD PRs.
/// Suggests opener / 2nd / 3rd attempts at three confidence levels.
/// "Copy to Meet" logs all suggestions to the active meet as `not_taken`.
class AttemptCalculatorSheet extends ConsumerStatefulWidget {
  const AttemptCalculatorSheet({super.key});

  @override
  ConsumerState<AttemptCalculatorSheet> createState() =>
      _AttemptCalculatorSheetState();
}

class _AttemptCalculatorSheetState
    extends ConsumerState<AttemptCalculatorSheet> {
  // Percentages of training max per confidence level.
  static const Map<_Confidence, List<double>> _percents = {
    _Confidence.conservative: [0.90, 0.96, 1.01],
    _Confidence.standard: [0.91, 0.98, 1.03],
    _Confidence.aggressive: [0.92, 1.00, 1.05],
  };

  _Confidence _confidence = _Confidence.standard;
  bool _copying = false;

  final _squatCtrl = TextEditingController();
  final _benchCtrl = TextEditingController();
  final _deadliftCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final sbd = ref.read(sbdTotalProvider).value;
    if (sbd?.squat != null) _squatCtrl.text = sbd!.squat!.toStringAsFixed(1);
    if (sbd?.bench != null) _benchCtrl.text = sbd!.bench!.toStringAsFixed(1);
    if (sbd?.deadlift != null) {
      _deadliftCtrl.text = sbd!.deadlift!.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _squatCtrl.dispose();
    _benchCtrl.dispose();
    _deadliftCtrl.dispose();
    super.dispose();
  }

  double _roundTo2p5(double kg) => (kg / 2.5).round() * 2.5;

  List<double>? _suggestions(TextEditingController ctrl) {
    final max = double.tryParse(ctrl.text.trim());
    if (max == null || max <= 0) return null;
    return _percents[_confidence]!
        .map((p) => _roundTo2p5(max * p))
        .toList();
  }

  Future<void> _copyToMeet() async {
    setState(() => _copying = true);
    final messenger = ScaffoldMessenger.of(context);
    int saved = 0;
    int total = 0;

    final entries = [
      ('squat', _squatCtrl),
      ('bench', _benchCtrl),
      ('deadlift', _deadliftCtrl),
    ];
    for (final (liftType, ctrl) in entries) {
      final suggestions = _suggestions(ctrl);
      if (suggestions == null) continue;
      total += 3;
      for (int i = 0; i < 3; i++) {
        try {
          await ref.read(activeMeetProvider.notifier).logAttempt(
                liftType: liftType,
                attemptNumber: i + 1,
                weightKg: suggestions[i],
                result: 'not_taken',
              );
          saved++;
        } catch (_) {
          // Individual failure — continue. Optimistic update already shows
          // the attempt; user can retry via "Copy to Meet" (upserts are idempotent).
        }
      }
    }

    if (!mounted) return;
    setState(() => _copying = false);
    if (saved == total) {
      Navigator.of(context).pop();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$saved of $total attempts saved. Tap "Copy to Meet" again to retry.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final squat = _suggestions(_squatCtrl);
    final bench = _suggestions(_benchCtrl);
    final deadlift = _suggestions(_deadliftCtrl);
    final hasAny = squat != null || bench != null || deadlift != null;
    final hasMeet = ref.watch(activeMeetProvider) != null;
    final percents = _percents[_confidence]!;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  'Attempt Calculator',
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter training maxes to generate suggested attempts.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),

                // Confidence selector
                Text('Confidence', style: textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<_Confidence>(
                  segments: const [
                    ButtonSegment(
                      value: _Confidence.conservative,
                      label: Text('Conservative'),
                    ),
                    ButtonSegment(
                      value: _Confidence.standard,
                      label: Text('Standard'),
                    ),
                    ButtonSegment(
                      value: _Confidence.aggressive,
                      label: Text('Aggressive'),
                    ),
                  ],
                  selected: {_confidence},
                  onSelectionChanged: (v) =>
                      setState(() => _confidence = v.first),
                ),
                const SizedBox(height: 20),

                // Training max inputs
                Text('Training Maxes', style: textTheme.labelLarge),
                const SizedBox(height: 12),
                _MaxField(
                  label: 'Squat (kg)',
                  ctrl: _squatCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                _MaxField(
                  label: 'Bench (kg)',
                  ctrl: _benchCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                _MaxField(
                  label: 'Deadlift (kg)',
                  ctrl: _deadliftCtrl,
                  onChanged: (_) => setState(() {}),
                ),

                // Suggestions
                if (hasAny) ...[
                  const SizedBox(height: 24),
                  Text('Suggested Attempts', style: textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${(percents[0] * 100).round()}% / '
                    '${(percents[1] * 100).round()}% / '
                    '${(percents[2] * 100).round()}% of training max · '
                    'rounded to 2.5 kg',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  _SuggestionsTable(
                    squat: squat,
                    bench: bench,
                    deadlift: deadlift,
                  ),
                ],

                // Copy to meet button
                if (hasMeet && hasAny) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _copying ? null : _copyToMeet,
                    icon: _copying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.copy_all),
                    label: const Text('Copy to Meet'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pre-fills all 9 attempt slots as "not taken" with suggested weights.',
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],

                if (!hasMeet && hasAny) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Start a meet to use "Copy to Meet".',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _MaxField extends StatelessWidget {
  const _MaxField({
    required this.label,
    required this.ctrl,
    required this.onChanged,
  });

  final String label;
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^(\d+\.?\d*)?$')),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixText: 'kg',
      ),
      onChanged: onChanged,
    );
  }
}

class _SuggestionsTable extends StatelessWidget {
  const _SuggestionsTable({
    required this.squat,
    required this.bench,
    required this.deadlift,
  });

  final List<double>? squat;
  final List<double>? bench;
  final List<double>? deadlift;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final headerStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Header row
            Container(
              color: colorScheme.surfaceContainerHigh,
              child: _TableRow(
                label: 'Lift',
                values: const ['Opener', '2nd', '3rd'],
                labelStyle: headerStyle,
                valueStyle: headerStyle,
                isHeader: true,
              ),
            ),
            if (squat != null) ...[
              const Divider(height: 1),
              _TableRow(
                label: 'Squat',
                values: squat!
                    .map((v) => '${v.toStringAsFixed(1)} kg')
                    .toList(),
                labelStyle: textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                valueStyle: textTheme.bodySmall,
                thirdStyle: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (bench != null) ...[
              const Divider(height: 1),
              _TableRow(
                label: 'Bench',
                values: bench!
                    .map((v) => '${v.toStringAsFixed(1)} kg')
                    .toList(),
                labelStyle: textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                valueStyle: textTheme.bodySmall,
                thirdStyle: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (deadlift != null) ...[
              const Divider(height: 1),
              _TableRow(
                label: 'Deadlift',
                values: deadlift!
                    .map((v) => '${v.toStringAsFixed(1)} kg')
                    .toList(),
                labelStyle: textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                valueStyle: textTheme.bodySmall,
                thirdStyle: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.label,
    required this.values,
    required this.labelStyle,
    required this.valueStyle,
    this.thirdStyle,
    this.isHeader = false,
  });

  final String label;
  final List<String> values;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final TextStyle? thirdStyle;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(label, style: labelStyle),
          ),
          for (int i = 0; i < values.length; i++)
            Expanded(
              child: Text(
                values[i],
                textAlign: TextAlign.center,
                style: (i == 2 && !isHeader) ? thirdStyle : valueStyle,
              ),
            ),
        ],
      ),
    );
  }
}
