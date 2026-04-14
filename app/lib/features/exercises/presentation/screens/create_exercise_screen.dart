import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../providers/exercise_form_provider.dart';
import '../../providers/exercise_providers.dart';

class CreateExerciseScreen extends ConsumerWidget {
  const CreateExerciseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(exerciseFormProvider);
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);

    // Navigate back on successful submission. Guard against double-firing by
    // comparing previous state — if submitted was already true we skip.
    ref.listen<ExerciseFormState>(exerciseFormProvider, (previous, next) {
      final wasSubmitted = previous?.submitted ?? false;
      if (next.submitted && !wasSubmitted && context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom exercise created!')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create Exercise')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error banner
            if (formState.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _errorMessage(formState.error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),

            // Name
            TextField(
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  ref.read(exerciseFormProvider.notifier).setName(v),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (v) =>
                  ref.read(exerciseFormProvider.notifier).setDescription(v),
            ),
            const SizedBox(height: 12),

            // Exercise type
            Text(
              'Type *',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<ExerciseType>(
              segments: const [
                ButtonSegment(
                  value: ExerciseType.strength,
                  label: Text('Strength'),
                  icon: Icon(Icons.fitness_center),
                ),
                ButtonSegment(
                  value: ExerciseType.cardio,
                  label: Text('Cardio'),
                  icon: Icon(Icons.directions_run),
                ),
                ButtonSegment(
                  value: ExerciseType.stretching,
                  label: Text('Stretch'),
                  icon: Icon(Icons.self_improvement),
                ),
              ],
              selected: {formState.exerciseType},
              onSelectionChanged: (selection) => ref
                  .read(exerciseFormProvider.notifier)
                  .setExerciseType(selection.first),
            ),
            const SizedBox(height: 12),

            // Instructions
            TextField(
              decoration: const InputDecoration(
                labelText: 'Instructions',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              onChanged: (v) =>
                  ref.read(exerciseFormProvider.notifier).setInstructions(v),
            ),
            const SizedBox(height: 16),

            // Muscle groups
            Text(
              'Muscle Groups',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'First selected is primary (★). Tap a selected group to promote it.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            muscleGroupsAsync.when(
              data: (groups) => Wrap(
                spacing: 6,
                runSpacing: 4,
                children: groups.map((mg) {
                  final selected = formState.selectedMuscleGroups
                      .where((m) => m.muscleGroupId == mg.id)
                      .firstOrNull;
                  final isSelected = selected != null;
                  final isPrimary = selected?.isPrimary ?? false;
                  return FilterChip(
                    label: Text(mg.displayName),
                    selected: isSelected,
                    avatar: isPrimary
                        ? Icon(
                            Icons.star,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onSelected: (value) => ref
                        .read(exerciseFormProvider.notifier)
                        .toggleMuscleGroup(
                          muscleGroupId: mg.id,
                          displayName: mg.displayName,
                        ),
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => const Text('Could not load muscle groups.'),
            ),
            const SizedBox(height: 24),

            // Submit
            FilledButton(
              onPressed: formState.isLoading
                  ? null
                  : () => ref.read(exerciseFormProvider.notifier).submit(),
              child: formState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Exercise'),
            ),
          ],
        ),
      ),
    );
  }
}

String _errorMessage(AppException error) {
  if (error is NetworkException) return 'No internet connection.';
  if (error is UnauthorizedException) return 'Not authorised.';
  if (error is ServerException) {
    return error.message ?? 'Server error ${error.statusCode}.';
  }
  if (error is ValidationException) return error.message ?? 'Validation error.';
  if (error is CancelledException) return 'Cancelled.';
  if (error is UnknownException) {
    return error.message ?? 'An unexpected error occurred.';
  }
  return 'An unexpected error occurred.';
}
