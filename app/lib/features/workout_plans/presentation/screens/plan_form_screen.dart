import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../providers/plan_form_provider.dart';
import '../../providers/plan_form_state.dart';
import '../widgets/draggable_exercise_item.dart';
import 'exercise_picker_screen.dart';

/// Multi-step create/edit workout plan screen.
///
/// Pass [planId] = null for create mode, or a plan UUID for edit mode.
class PlanFormScreen extends ConsumerStatefulWidget {
  const PlanFormScreen({super.key, required this.planId});

  final String? planId;

  @override
  ConsumerState<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends ConsumerState<PlanFormScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(planFormProvider(widget.planId));
    final isEditMode = widget.planId != null;

    // Listen for save completion to navigate away.
    ref.listen<PlanFormState>(
      planFormProvider(widget.planId),
      (previous, next) {
        if (next.saved && !(previous?.saved ?? false)) {
          if (next.savedPlanId != null) {
            // Saved → go to detail screen.
            context.go(AppRoutes.planDetailPath(next.savedPlanId!));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isEditMode ? 'Plan updated.' : 'Plan created.',
                ),
              ),
            );
          } else {
            // Deleted → go to plan list.
            context.go(AppRoutes.plans);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Plan deleted.')),
            );
          }
        }
        // Show save error as a snackbar.
        if (next.saveError != null &&
            next.saveError != previous?.saveError) {
          final msg = next.saveError!.when(
            network: (_) => 'No network connection. Please try again.',
            unauthorized: (_) => 'Session expired. Please log in again.',
            serverError: (_, m) => m ?? 'Server error. Please try again.',
            validation: (m, _) => m ?? 'Validation error.',
            cancelled: () => null,
            unknown: (m) => m ?? 'An unexpected error occurred.',
          );
          if (msg != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.red),
            );
          }
        }
      },
    );

    // When the provider detects that advancing to exercises would drop existing
    // exercise assignments, show a confirmation dialog before proceeding.
    ref.listen<bool>(
      planFormProvider(widget.planId).select((s) => s.pendingScheduleRebuild),
      (_, pending) async {
        if (!pending) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Clear exercise assignments?'),
            content: const Text(
              'Changing your schedule removes exercises from days that '
              'no longer exist in the new layout. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (!context.mounted) return;
        final notifier = ref.read(planFormProvider(widget.planId).notifier);
        if (confirmed == true) {
          notifier.confirmScheduleRebuild();
        } else {
          notifier.cancelScheduleRebuild();
        }
      },
    );

    // Animate the PageView whenever the provider's currentStep changes.
    // Using ref.listen (not addPostFrameCallback) so animation only fires
    // on actual step transitions, not on every build.
    ref.listen<PlanFormStep>(
      planFormProvider(widget.planId).select((s) => s.currentStep),
      (previous, next) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            next.index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Plan' : 'New Plan'),
        actions: [
          if (isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete plan',
              onPressed: formState.isSaving ? null : () => _confirmDelete(context),
            ),
        ],
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: formState.currentStep),
          Expanded(
            child: PageView(
              controller: _pageController,
              // Navigation is driven by the buttons, not by swipe.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _DetailsPage(planId: widget.planId),
                _SchedulePage(planId: widget.planId),
                _ExercisesPage(planId: widget.planId),
              ],
            ),
          ),
          if (formState.saveError != null &&
              formState.currentStep == PlanFormStep.exercises)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                formState.saveError!.when(
                  validation: (m, _) => m ?? 'Add at least one exercise',
                  network: (_) => 'No network. Check your connection.',
                  unauthorized: (_) => 'Session expired.',
                  serverError: (_, m) => m ?? 'Server error.',
                  cancelled: () => '',
                  unknown: (m) => m ?? 'An unexpected error occurred.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          _NavigationRow(
            planId: widget.planId,
            pageController: _pageController,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: const Text(
          'This plan and all its workout data will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(planFormProvider(widget.planId).notifier).deletePlan();
    }
  }
}

// ---------------------------------------------------------------------------
// Step indicator
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final PlanFormStep currentStep;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const steps = PlanFormStep.values;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: steps.map((step) {
          final isActive = step == currentStep;
          final isDone = step.index < currentStep.index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: (isActive || isDone)
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation row (Back / Next / Save)
// ---------------------------------------------------------------------------

class _NavigationRow extends ConsumerWidget {
  const _NavigationRow({
    required this.planId,
    required this.pageController,
  });

  final String? planId;
  final PageController pageController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(planFormProvider(planId));
    final notifier = ref.read(planFormProvider(planId).notifier);
    final isFirst = formState.currentStep == PlanFormStep.details;
    final isLast = formState.currentStep == PlanFormStep.exercises;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            if (!isFirst)
              Expanded(
                child: OutlinedButton(
                  onPressed: formState.isSaving
                      ? null
                      : () {
                          final prevStep = PlanFormStep
                              .values[formState.currentStep.index - 1];
                          notifier.goToStep(prevStep);
                        },
                  child: const Text('Back'),
                ),
              ),
            if (!isFirst) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: formState.isSaving
                    ? null
                    : () {
                        if (isLast) {
                          notifier.save();
                        } else {
                          final nextStep = PlanFormStep
                              .values[formState.currentStep.index + 1];
                          notifier.goToStep(nextStep);
                        }
                      },
                child: formState.isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isLast ? 'Save Plan' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 0 — Plan details
// ---------------------------------------------------------------------------

class _DetailsPage extends ConsumerStatefulWidget {
  const _DetailsPage({required this.planId});
  final String? planId;

  @override
  ConsumerState<_DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends ConsumerState<_DetailsPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    final state = ref.read(planFormProvider(widget.planId));
    _nameCtrl = TextEditingController(text: state.name);
    _descCtrl = TextEditingController(text: state.description);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When the provider finishes seeding from Drift in edit mode (isSeeding
    // transitions false → true → false), re-populate the text controllers so
    // they reflect the plan's actual name and description.
    ref.listen<bool>(
      planFormProvider(widget.planId).select((s) => s.isSeeding),
      (wasSeeding, isSeeding) {
        if (wasSeeding == true && !isSeeding) {
          final state = ref.read(planFormProvider(widget.planId));
          _nameCtrl.text = state.name;
          _descCtrl.text = state.description;
        }
      },
    );

    final nameError = ref.watch(
      planFormProvider(widget.planId).select((s) => s.fieldErrors['name']),
    );
    final notifier = ref.read(planFormProvider(widget.planId).notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Plan details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Plan name *',
              border: const OutlineInputBorder(),
              errorText: nameError,
            ),
            onChanged: notifier.setName,
          ),
          const SizedBox(height: 16),
          TextField(
            maxLines: 3,
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: notifier.setDescription,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1 — Schedule configuration
// ---------------------------------------------------------------------------

class _SchedulePage extends ConsumerWidget {
  const _SchedulePage({required this.planId});
  final String? planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(planFormProvider(planId));
    final notifier = ref.read(planFormProvider(planId).notifier);
    final daysError = formState.fieldErrors['days'];
    final isRecurring = formState.scheduleType == ScheduleType.recurring;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Schedule type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<ScheduleType>(
            segments: const [
              ButtonSegment(
                value: ScheduleType.weekly,
                label: Text('Weekly'),
                icon: Icon(Icons.calendar_view_week),
              ),
              ButtonSegment(
                value: ScheduleType.recurring,
                label: Text('Recurring'),
                icon: Icon(Icons.repeat),
              ),
            ],
            selected: {formState.scheduleType},
            onSelectionChanged: (selected) =>
                notifier.setScheduleType(selected.first),
          ),
          const SizedBox(height: 8),
          Text(
            isRecurring
                ? 'Repeat the selected days across multiple weeks.'
                : 'Same days every week.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),

          // Weeks count picker (recurring only)
          if (isRecurring) ...[
            const SizedBox(height: 16),
            Text(
              'Number of weeks',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: formState.weeksCount,
                  isDense: true,
                  items: List.generate(12, (i) => i + 2)
                      .map(
                        (w) => DropdownMenuItem(
                          value: w,
                          child: Text('$w weeks'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) notifier.setWeeksCount(v);
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          Text(
            'Training days',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _DaySelector(
            selected: formState.selectedDays,
            onToggle: notifier.toggleDay,
          ),
          if (daysError != null) ...[
            const SizedBox(height: 6),
            Text(
              daysError,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selected,
    required this.onToggle,
  });

  final Set<int> selected;
  final void Function(int dayOfWeek) onToggle;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (i) {
        final isSelected = selected.contains(i);
        return FilterChip(
          label: Text(_days[i]),
          selected: isSelected,
          onSelected: (_) => onToggle(i),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2 — Exercises per day
// ---------------------------------------------------------------------------

class _ExercisesPage extends ConsumerWidget {
  const _ExercisesPage({required this.planId});
  final String? planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(planFormProvider(planId));
    final days = formState.days;

    if (days.isEmpty) {
      return const Center(
        child: Text('No days selected. Go back to configure your schedule.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: days.length,
      itemBuilder: (context, dayIndex) {
        final day = days[dayIndex];
        final title = _dayTitle(day.dayOfWeek, day.weekNumber);
        return _DayExercisesSection(
          planId: planId,
          dayIndex: dayIndex,
          title: title,
        );
      },
    );
  }

  static const _dayNames = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  String _dayTitle(int dayOfWeek, int? weekNumber) {
    final day = _dayNames[dayOfWeek];
    return weekNumber != null ? 'Week $weekNumber — $day' : day;
  }
}

class _DayExercisesSection extends ConsumerWidget {
  const _DayExercisesSection({
    required this.planId,
    required this.dayIndex,
    required this.title,
  });

  final String? planId;
  final int dayIndex;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(
      planFormProvider(planId).select((s) => s.days[dayIndex]),
    );
    final notifier = ref.read(planFormProvider(planId).notifier);
    final exercises = day.exercises;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: exercises.isEmpty
            ? Text(
                'No exercises yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            : Text(
                '${exercises.length} exercise${exercises.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
        children: [
          if (exercises.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exercises.length,
              itemBuilder: (context, exerciseIndex) {
                final ex = exercises[exerciseIndex];
                return DraggableExerciseItem(
                  // Use the stable localId as the key so Flutter preserves
                  // widget state correctly across reorders.
                  key: ValueKey(ex.localId),
                  planId: planId,
                  dayIndex: dayIndex,
                  exerciseIndex: exerciseIndex,
                  exercise: ex,
                  onRemove: () =>
                      notifier.removeExercise(dayIndex, exerciseIndex),
                );
              },
              onReorder: (oldIndex, newIndex) =>
                  notifier.reorderExercises(dayIndex, oldIndex, newIndex),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add exercises'),
              onPressed: () => _openPicker(context, ref, dayIndex),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    WidgetRef ref,
    int dayIndex,
  ) async {
    final result = await Navigator.of(context).push<List<Exercise>>(
      MaterialPageRoute(
        builder: (_) => const ExercisePickerScreen(),
        fullscreenDialog: true,
      ),
    );
    if (result != null && result.isNotEmpty) {
      ref.read(planFormProvider(planId).notifier).addExercises(dayIndex, result);
    }
  }
}
