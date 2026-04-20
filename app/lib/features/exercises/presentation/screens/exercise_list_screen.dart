import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../providers/exercise_list_provider.dart';
import '../widgets/exercise_card.dart';
import '../widgets/exercise_filter_bar.dart';

class ExerciseListScreen extends ConsumerWidget {
  const ExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exerciseListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create custom exercise',
        onPressed: () => context.push(AppRoutes.createExercise),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const ExerciseFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: exercisesAsync.when(
              data: (exercises) {
                if (exercises.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No exercises found.\nTry adjusting your filters.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(exerciseListProvider.notifier).refresh(),
                  child: ListView.separated(
                    itemCount: exercises.length,
                    separatorBuilder: (ctx, i) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      return ExerciseCard(
                        exercise: exercise,
                        onTap: () => context.push(
                          AppRoutes.exerciseDetailPath(exercise.id),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => RefreshIndicator(
                onRefresh: () =>
                    ref.read(exerciseListProvider.notifier).refresh(),
                child: ListView(
                  children: [
                    const SizedBox(height: 64),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'Could not load exercises.\nPull down to retry.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
