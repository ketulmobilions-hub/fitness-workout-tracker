import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/exercise_detail_provider.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
  });

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseAsync = ref.watch(exerciseDetailProvider(exerciseId));

    return Scaffold(
      appBar: AppBar(
        title: exerciseAsync.when(
          data: (exercise) => Text(exercise?.name ?? 'Exercise'),
          loading: () => const Text('Exercise'),
          error: (e, s) => const Text('Exercise'),
        ),
        actions: exerciseAsync.when(
          data: (exercise) {
            if (exercise == null || !exercise.isCustom) return null;
            return [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete exercise',
                onPressed: () => _confirmDelete(context, ref),
              ),
            ];
          },
          loading: () => null,
          error: (e, s) => null,
        ),
      ),
      body: exerciseAsync.when(
        data: (exercise) {
          if (exercise == null) {
            return const Center(child: Text('Exercise not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Type badge
              Row(
                children: [
                  _TypeBadge(type: exercise.exerciseType),
                  if (exercise.isCustom) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: const Text('Custom'),
                      avatar: const Icon(Icons.person, size: 14),
                      labelStyle: Theme.of(context).textTheme.labelSmall,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Description
              if (exercise.description != null) ...[
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(exercise.description!),
                const SizedBox(height: 16),
              ],

              // Muscle groups
              if (exercise.muscleGroups.isNotEmpty) ...[
                Text(
                  'Muscle Groups',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: exercise.muscleGroups
                      .map((mg) => _MuscleGroupChip(muscleGroup: mg))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Instructions
              if (exercise.instructions != null) ...[
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(exercise.instructions!),
                const SizedBox(height: 16),
              ],

              // Media
              if (exercise.mediaUrl != null) ...[
                Text(
                  'Media',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    exercise.mediaUrl!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        height: 220,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (ctx, err, st) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Could not load exercise details. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete exercise?'),
        content: const Text(
          'This will permanently delete your custom exercise. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // Delete is handled by the notifier — no business logic in the widget.
      await ref.read(exerciseDetailProvider(exerciseId).notifier).delete();
      if (context.mounted) context.pop();
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not delete exercise. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final ExerciseType type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      ExerciseType.strength => (
          'Strength',
          Theme.of(context).colorScheme.primaryContainer,
        ),
      ExerciseType.cardio => (
          'Cardio',
          Theme.of(context).colorScheme.tertiaryContainer,
        ),
      ExerciseType.stretching => (
          'Stretching',
          Theme.of(context).colorScheme.secondaryContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _MuscleGroupChip extends StatelessWidget {
  const _MuscleGroupChip({required this.muscleGroup});

  final MuscleGroup muscleGroup;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(muscleGroup.displayName),
      avatar: muscleGroup.isPrimary
          ? Icon(
              Icons.star,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      labelStyle: Theme.of(context).textTheme.labelSmall,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
