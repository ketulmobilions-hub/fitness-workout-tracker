import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/dio_provider.dart';
import '../data/exercise_repository_impl.dart';

part 'exercise_providers.g.dart';

@riverpod
ExerciseApiClient exerciseApiClient(Ref ref) {
  return ExerciseApiClient(ref.watch(dioProvider));
}

@Riverpod(keepAlive: true)
ExerciseRepository exerciseRepository(Ref ref) {
  return ExerciseRepositoryImpl(
    apiClient: ref.watch(exerciseApiClientProvider),
    exerciseDao: ref.watch(appDatabaseProvider).exerciseDao,
  );
}

/// Reactive stream of all muscle groups from the local cache — routed through
/// the repository (not the DAO directly) to respect the VGV layer contract.
@Riverpod(keepAlive: true)
Stream<List<MuscleGroup>> muscleGroups(Ref ref) {
  return ref.watch(exerciseRepositoryProvider).watchMuscleGroups();
}
