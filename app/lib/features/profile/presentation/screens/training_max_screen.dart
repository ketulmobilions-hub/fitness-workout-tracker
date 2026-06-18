import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/training_max_providers.dart';

// Allowed percentages for the segment selector.
const _kPctOptions = [85.0, 87.5, 90.0, 92.5, 95.0];

class TrainingMaxScreen extends ConsumerWidget {
  const TrainingMaxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tmAsync = ref.watch(trainingMaxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Maxes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(trainingMaxProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: tmAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load training maxes',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.read(trainingMaxProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (List<TrainingMax> tms) => _TrainingMaxList(tms: tms),
      ),
    );
  }
}

class _TrainingMaxList extends ConsumerWidget {
  const _TrainingMaxList({required this.tms});
  final List<TrainingMax> tms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No training maxes set',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button on any exercise in your workout plan to set a training max for it.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Detect TMs that are stale relative to a newer PR.
    final stale = tms
        .where((t) => _isStaleTm(t))
        .map((t) => t.exerciseId)
        .toSet();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tms.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final tm = tms[index];
        return _TrainingMaxTile(
          tm: tm,
          hasSuggestion: stale.contains(tm.exerciseId),
          onEdit: () => _showEditSheet(context, ref, tm),
        );
      },
    );
  }

  bool _isStaleTm(TrainingMax tm) {
    final pr = tm.latestPrKg;
    if (pr == null) return false;
    final prDate = tm.latestPrDate;
    if (prDate == null) return false;
    // PR was set after the TM was last updated — TM may be out of date.
    if (!prDate.isAfter(tm.updatedAt)) return false;
    final expected = pr * (tm.percentageOf1rm / 100);
    // Flag if the stored TM differs from expected by more than 0.5 kg.
    return (tm.trainingMaxKg - expected).abs() > 0.5;
  }

  Future<void> _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    TrainingMax tm,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditTrainingMaxSheet(tm: tm),
    );
  }
}

class _TrainingMaxTile extends StatelessWidget {
  const _TrainingMaxTile({
    required this.tm,
    required this.hasSuggestion,
    required this.onEdit,
  });

  final TrainingMax tm;
  final bool hasSuggestion;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final suggested = tm.latestPrKg != null
        ? tm.latestPrKg! * (tm.percentageOf1rm / 100)
        : null;

    return ListTile(
      title: Text(tm.exerciseName),
      subtitle: Text(
        '${tm.trainingMaxKg.toStringAsFixed(1)} kg '
        '(${_fmtPct(tm.percentageOf1rm)}% of 1RM)',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: hasSuggestion
          ? Tooltip(
              message: 'New PR detected — suggested TM: '
                  '${suggested!.toStringAsFixed(1)} kg',
              child: Icon(Icons.new_releases, color: cs.primary, size: 20),
            )
          : null,
      onTap: onEdit,
    );
  }

  String _fmtPct(double pct) =>
      pct == pct.truncateToDouble() ? pct.toInt().toString() : pct.toString();
}

class _EditTrainingMaxSheet extends ConsumerStatefulWidget {
  const _EditTrainingMaxSheet({required this.tm});
  final TrainingMax tm;

  @override
  ConsumerState<_EditTrainingMaxSheet> createState() =>
      _EditTrainingMaxSheetState();
}

class _EditTrainingMaxSheetState extends ConsumerState<_EditTrainingMaxSheet> {
  late final TextEditingController _controller;
  late double _pct;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.tm.trainingMaxKg.toStringAsFixed(1),
    );
    // Clamp to nearest option — handles legacy values set outside the picker.
    _pct = _kPctOptions.reduce((a, b) =>
        (a - widget.tm.percentageOf1rm).abs() <
                (b - widget.tm.percentageOf1rm).abs()
            ? a
            : b);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pr = widget.tm.latestPrKg;
    final hasPrSuggestion = pr != null &&
        widget.tm.latestPrDate != null &&
        widget.tm.latestPrDate!.isAfter(widget.tm.updatedAt);
    // Use stored percentageOf1rm for the suggestion — this matches the badge
    // logic in _isStaleTm so the "suggested TM" shown here is consistent with
    // what triggered the badge on the list tile.
    final storedPct = widget.tm.percentageOf1rm;
    final suggested = pr != null ? pr * (storedPct / 100) : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.tm.exerciseName, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Training Max — used for % calculations in your program',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // Suggestion banner shown when a new PR has been logged since the
          // last TM update.
          if (hasPrSuggestion && suggested != null) ...[
            _SuggestionBanner(
              prKg: pr!,
              suggestedKg: suggested,
              pct: storedPct,
              onAccept: () =>
                  _controller.text = suggested.toStringAsFixed(1),
            ),
            const SizedBox(height: 16),
          ],

          // TM weight input
          TextField(
            controller: _controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Training Max (kg)',
              border: OutlineInputBorder(),
              suffixText: 'kg',
            ),
          ),
          const SizedBox(height: 16),

          // % of 1RM selector
          Text('% of 1RM', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<double>(
              segments: _kPctOptions
                  .map((p) => ButtonSegment<double>(
                        value: p,
                        label: Text(_fmtPct(p)),
                      ))
                  .toList(),
              selected: {_pct},
              onSelectionChanged: (s) => setState(() => _pct = s.first),
            ),
          ),
          const SizedBox(height: 8),
          if (pr != null)
            Text(
              'Latest PR: ${pr.toStringAsFixed(1)} kg  →  '
              'TM at $_pct%: ${(pr * _pct / 100).toStringAsFixed(1)} kg',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final kg = double.tryParse(_controller.text.trim());
    if (kg == null || kg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight')),
      );
      return;
    }

    // Capture messenger before the async gap — context may be unmounted by
    // the time the network call returns if the user navigates away.
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    try {
      await ref.read(trainingMaxProvider.notifier).upsert(
            exerciseId: widget.tm.exerciseId,
            trainingMaxKg: kg,
            percentageOf1rm: _pct,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to save training max. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtPct(double pct) =>
      pct == pct.truncateToDouble() ? pct.toInt().toString() : pct.toString();
}

class _SuggestionBanner extends StatelessWidget {
  const _SuggestionBanner({
    required this.prKg,
    required this.suggestedKg,
    required this.pct,
    required this.onAccept,
  });

  final double prKg;
  final double suggestedKg;
  final double pct;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pctLabel =
        pct == pct.truncateToDouble() ? pct.toInt().toString() : '$pct';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: cs.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'New PR: ${prKg.toStringAsFixed(1)} kg  →  '
              'Update TM to ${suggestedKg.toStringAsFixed(1)} kg ($pctLabel%)?',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAccept,
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
