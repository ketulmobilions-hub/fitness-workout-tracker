import 'package:dio/dio.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../providers/template_provider.dart';
import '../../providers/workout_plan_providers.dart';

class TemplateDetailScreen extends ConsumerWidget {
  const TemplateDetailScreen({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateAsync = ref.watch(templateDetailProvider(templateId));

    return Scaffold(
      appBar: AppBar(title: const Text('Program Details')),
      body: templateAsync.when(
        data: (template) => _TemplateDetailBody(template: template),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not load template.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(templateDetailProvider(templateId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — shown once template data is loaded
// ---------------------------------------------------------------------------

class _TemplateDetailBody extends ConsumerWidget {
  const _TemplateDetailBody({required this.template});

  final ProgramTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(
              left: 16, right: 16, top: 16, bottom: 100),
          children: [
            _TemplateHeader(template: template),
            const SizedBox(height: 24),
            Text('Week 1 Preview',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (template.weeks.isNotEmpty)
              ...template.weeks.first.days
                  .map((day) => _DayPreviewCard(day: day))
            else
              const Text('No preview available.'),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _ImportBar(template: template),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header — name, meta chips, description
// ---------------------------------------------------------------------------

class _TemplateHeader extends StatelessWidget {
  const _TemplateHeader({required this.template});

  final ProgramTemplate template;

  static const _difficultyColor = {
    'beginner': Colors.green,
    'intermediate': Colors.orange,
    'advanced': Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    final diffColor =
        _difficultyColor[template.difficulty] ?? Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(template.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Chip(
              label: Text(template.difficulty,
                  style: TextStyle(
                      color: diffColor, fontWeight: FontWeight.w600)),
              backgroundColor: diffColor.withValues(alpha: 0.12),
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Chip(
              label: Text('${template.weeksCount} weeks'),
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Chip(
              label: Text('${template.daysPerWeek} days/wk'),
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            ...template.tags.map(
              (tag) => Chip(
                label: Text(tag),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(template.description,
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Day preview card — shows exercises for one training day
// ---------------------------------------------------------------------------

class _DayPreviewCard extends StatelessWidget {
  const _DayPreviewCard({required this.day});

  final TemplateDay day;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  day.dayName,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(
                          color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    day.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...day.exercises.map((ex) => _ExerciseRow(exercise: ex)),
          ],
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final TemplateExercise exercise;

  String get _targetLabel {
    final sets = exercise.targetSets;
    final reps = exercise.targetReps;
    final pct = exercise.targetWeightPct1rm;
    final rpe = exercise.targetRpe;

    if (sets <= 0) return '—';
    final setsReps = reps != null ? '${sets}×$reps' : '${sets}×?';

    if (pct != null) {
      // Multiply by 40 (= 1/0.025) and round to avoid float precision errors
      // before converting back. e.g. 0.575×100 = 57.50000000000001 in IEEE 754.
      final pctInt = (pct * 40).round(); // e.g. 23 for 0.575
      final pctVal = pctInt * 2.5; // e.g. 57.5
      final pctStr = pctVal == pctVal.truncateToDouble()
          ? '${pctVal.toInt()}%'
          : '${pctVal.toStringAsFixed(1)}%';
      return '$setsReps @ $pctStr 1RM';
    }
    if (rpe != null) {
      final rpeStr = rpe == rpe.truncateToDouble()
          ? rpe.toInt().toString()
          : rpe.toStringAsFixed(1);
      return '$setsReps @ RPE $rpeStr';
    }
    return setsReps;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              exercise.exerciseName,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _targetLabel,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Import bar — sticky bottom button + dialog
// ---------------------------------------------------------------------------

class _ImportBar extends ConsumerWidget {
  const _ImportBar({required this.template});

  final ProgramTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: FilledButton.icon(
        onPressed: () => _showImportSheet(context, ref),
        icon: const Icon(Icons.download_rounded),
        label: const Text('Import Program'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
        ),
      ),
    );
  }

  Future<void> _showImportSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ImportSheet(template: template),
    );
  }
}

// ---------------------------------------------------------------------------
// Import sheet — 1RM inputs + import action
// ---------------------------------------------------------------------------

class _ImportSheet extends ConsumerStatefulWidget {
  const _ImportSheet({required this.template});

  final ProgramTemplate template;

  @override
  ConsumerState<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<_ImportSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  final _squatCtrl = TextEditingController();
  final _benchCtrl = TextEditingController();
  final _deadliftCtrl = TextEditingController();
  final _ohpCtrl = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _squatCtrl.dispose();
    _benchCtrl.dispose();
    _deadliftCtrl.dispose();
    _ohpCtrl.dispose();
    super.dispose();
  }

  double? _parseMax(TextEditingController ctrl) {
    final s = ctrl.text.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  String? _validateMax(String? value) {
    if (value == null || value.isEmpty) return null;
    final d = double.tryParse(value);
    if (d == null || d <= 0) return 'Enter a positive number';
    return null;
  }

  Future<void> _import() async {
    if (!_formKey.currentState!.validate()) return;
    // Capture router before the async gap — after pop() the BuildContext
    // belonging to this sheet is detached from the tree.
    final router = GoRouter.of(context);
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(workoutPlanRepositoryProvider)
          .importTemplate(
            templateId: widget.template.id,
            name: _nameCtrl.text.trim(),
            squatMax: _parseMax(_squatCtrl),
            benchMax: _parseMax(_benchCtrl),
            deadliftMax: _parseMax(_deadliftCtrl),
            ohpMax: _parseMax(_ohpCtrl),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      router.push(AppRoutes.planDetailPath(result.planId));
    } catch (e) {
      if (!mounted) return;
      final message = e is DioException
          ? (e.response?.data?['message'] as String? ?? 'Import failed. Please try again.')
          : 'Import failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Import Program',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Enter your current maxes to auto-calculate first-week weights. '
              'You can skip any lifts.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Plan name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MaxField(
                    label: 'Squat 1RM',
                    controller: _squatCtrl,
                    validator: _validateMax,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MaxField(
                    label: 'Bench 1RM',
                    controller: _benchCtrl,
                    validator: _validateMax,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MaxField(
                    label: 'Deadlift 1RM',
                    controller: _deadliftCtrl,
                    validator: _validateMax,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MaxField(
                    label: 'OHP 1RM',
                    controller: _ohpCtrl,
                    validator: _validateMax,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _import,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Import'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _MaxField extends StatelessWidget {
  const _MaxField({
    required this.label,
    required this.controller,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'kg',
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}
