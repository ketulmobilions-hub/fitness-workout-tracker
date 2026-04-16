import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../workout_plans/workout_plans.dart';
import '../../providers/active_session_notifier.dart';
import '../widgets/previous_performance_card.dart';
import '../widgets/set_log_tile.dart';
import '../widgets/workout_timer.dart';

/// Full-screen workout logging UI.
///
/// Rendered once a session has been started via [ActiveSessionNotifier]. The
/// caller is responsible for calling [ActiveSessionNotifier.startSession] and
/// awaiting it before pushing this route.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(activeSessionProvider);

    if (sessionState == null) {
      // Session was cleared (completed or abandoned) — should have been
      // navigated away already, but show a fallback.
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: Text('No active workout.')),
      );
    }

    return _ActiveWorkoutBody(sessionState: sessionState);
  }
}

class _ActiveWorkoutBody extends ConsumerStatefulWidget {
  const _ActiveWorkoutBody({required this.sessionState});

  final ActiveSessionState sessionState;

  @override
  ConsumerState<_ActiveWorkoutBody> createState() => _ActiveWorkoutBodyState();
}

class _ActiveWorkoutBodyState extends ConsumerState<_ActiveWorkoutBody> {
  // ── Fix #8: single guard flag prevents both UI paths from racing ──────────
  // Both the "Finish" nav-bar button and the "Complete Workout" CTA call
  // _completeWorkout. Without this flag a user with one exercise can tap both
  // before the notifier's isLoading propagates, firing two completeSession
  // calls — the second throws StateError on an already-cleared session.
  bool _isCompleting = false;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _logSet({
    int? reps,
    double? weightKg,
    int? rpe,
    String? tempo,
    bool isWarmup = false,
  }) async {
    try {
      await ref.read(activeSessionProvider.notifier).logSet(
            reps: reps,
            weightKg: weightKg,
            rpe: rpe,
            tempo: tempo,
            isWarmup: isWarmup,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log set: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _deleteSet(SetLog setLog) async {
    await ref.read(activeSessionProvider.notifier).deleteSet(setLog);
  }

  Future<void> _completeWorkout() async {
    if (_isCompleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish workout?'),
        content: const Text(
            'This will save your workout and calculate any new personal records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCompleting = true);
    try {
      final summary =
          await ref.read(activeSessionProvider.notifier).completeSession();
      if (!mounted) return;
      context.pushReplacement(AppRoutes.workoutSummary, extra: summary);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not complete workout: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _abandonWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandon workout?'),
        content: const Text('Your logged sets will be discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(activeSessionProvider.notifier).abandonSession();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _pickAndAddExercise() async {
    final exercises = await Navigator.of(context).push<List<Exercise>>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercises == null || exercises.isEmpty || !mounted) return;

    for (final ex in exercises) {
      await ref.read(activeSessionProvider.notifier).addExercise(ex);
    }
  }

  Future<void> _pickAndReplaceExercise() async {
    final exercises = await Navigator.of(context).push<List<Exercise>>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercises == null || exercises.isEmpty || !mounted) return;

    await ref
        .read(activeSessionProvider.notifier)
        .replaceCurrentExercise(exercises.first);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(activeSessionProvider);
    if (sessionState == null) return const SizedBox.shrink();

    final session = sessionState.session;
    final currentEx =
        sessionState.hasExercises ? sessionState.currentExercise : null;
    final totalExercises = sessionState.exerciseData.length;
    final currentIndex = sessionState.currentExerciseIndex;

    return Scaffold(
      appBar: AppBar(
        title: WorkoutTimer(startTime: session.startedAt),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Abandon workout',
          onPressed: _abandonWorkout,
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'abandon') _abandonWorkout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'abandon',
                child: Text('Abandon workout'),
              ),
            ],
          ),
        ],
      ),
      body: currentEx == null
          ? _EmptyExerciseList(onAdd: _pickAndAddExercise)
          : _ExerciseLogger(
              exerciseData: currentEx,
              exerciseNumber: currentIndex + 1,
              totalExercises: totalExercises,
              isLoading: sessionState.isLoading,
              onLogSet: _logSet,
              onDeleteSet: _deleteSet,
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Exercise navigation row
              if (currentEx != null)
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: sessionState.isFirstExercise
                          ? null
                          : () => ref
                              .read(activeSessionProvider.notifier)
                              .previousExercise(),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Back'),
                    ),
                    const Spacer(),
                    _ExerciseDots(
                      total: totalExercises,
                      current: currentIndex,
                      onTap: (i) =>
                          ref
                              .read(activeSessionProvider.notifier)
                              .goToExercise(i),
                    ),
                    const Spacer(),
                    if (sessionState.isLastExercise)
                      OutlinedButton.icon(
                        onPressed: sessionState.isLoading || _isCompleting
                            ? null
                            : _completeWorkout,
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Finish'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: sessionState.isLoading
                            ? null
                            : () => ref
                                .read(activeSessionProvider.notifier)
                                .nextExercise(),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Next'),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              // Action row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _pickAndAddExercise,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                  TextButton.icon(
                    onPressed: currentEx == null
                        ? null
                        : () => ref
                            .read(activeSessionProvider.notifier)
                            .skipExercise(),
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Skip'),
                  ),
                  TextButton.icon(
                    onPressed: currentEx == null ? null : _pickAndReplaceExercise,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Replace'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: sessionState.isLoading || _isCompleting
                    ? null
                    : _completeWorkout,
                icon: sessionState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Complete Workout'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise logger section
// ---------------------------------------------------------------------------

class _ExerciseLogger extends StatelessWidget {
  const _ExerciseLogger({
    required this.exerciseData,
    required this.exerciseNumber,
    required this.totalExercises,
    required this.isLoading,
    required this.onLogSet,
    required this.onDeleteSet,
  });

  final ActiveExerciseData exerciseData;
  final int exerciseNumber;
  final int totalExercises;
  final bool isLoading;
  final void Function({
    int? reps,
    double? weightKg,
    int? rpe,
    String? tempo,
    bool isWarmup,
  }) onLogSet;
  final void Function(SetLog) onDeleteSet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ex = exerciseData.planExercise;
    final loggedSets = exerciseData.loggedSets;
    final nextSetNumber = loggedSets.length + 1;

    final lastSet = loggedSets.isNotEmpty ? loggedSets.last : null;

    return CustomScrollView(
      slivers: [
        // Exercise header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exercise $exerciseNumber of $totalExercises',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ex.exerciseName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (ex.targetSets != null || ex.targetReps != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _targetLabel(ex),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (ex.notes != null && ex.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      ex.notes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Previous performance
        SliverToBoxAdapter(
          child:
              PreviousPerformanceCard(previousSets: exerciseData.previousSets),
        ),

        // Logged sets
        if (loggedSets.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(top: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => LoggedSetTile(
                  set: loggedSets[i],
                  onDelete: () => onDeleteSet(loggedSets[i]),
                ),
                childCount: loggedSets.length,
              ),
            ),
          ),

        // New set input
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: SetInputRow(
              setNumber: nextSetNumber,
              previousWeight: lastSet?.weightKg,
              previousReps: lastSet?.reps,
              targetReps: ex.targetReps,
              targetSets: ex.targetSets,
              onLog: ({
                int? reps,
                double? weightKg,
                int? rpe,
                String? tempo,
                bool isWarmup = false,
              }) =>
                  onLogSet(
                reps: reps,
                weightKg: weightKg,
                rpe: rpe,
                tempo: tempo,
                isWarmup: isWarmup,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _targetLabel(PlanDayExercise ex) {
    final parts = <String>[];
    if (ex.targetSets != null) parts.add('${ex.targetSets} sets');
    if (ex.targetReps != null && ex.targetReps!.isNotEmpty) {
      parts.add('${ex.targetReps} reps');
    }
    return 'Target: ${parts.join(' × ')}';
  }
}

// ---------------------------------------------------------------------------
// Empty exercise list
// ---------------------------------------------------------------------------

class _EmptyExerciseList extends StatelessWidget {
  const _EmptyExerciseList({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text('No exercises added yet.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Exercise'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise dot navigation
// ---------------------------------------------------------------------------

class _ExerciseDots extends StatelessWidget {
  const _ExerciseDots({
    required this.total,
    required this.current,
    required this.onTap,
  });

  final int total;
  final int current;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    if (total > 10) {
      return Text(
        '${current + 1} / $total',
        style: Theme.of(context).textTheme.labelMedium,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 16 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
