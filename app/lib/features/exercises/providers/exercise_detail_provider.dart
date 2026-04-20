import 'package:fitness_domain/fitness_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'exercise_providers.dart';

part 'exercise_detail_provider.g.dart';

/// Streams a single [Exercise] with populated muscle groups.
/// Emits null when the exercise has been deleted from the local cache.
///
/// Also exposes [delete] so the presentation layer never calls the repository
/// directly — keeping business logic out of widgets.
@riverpod
class ExerciseDetail extends _$ExerciseDetail {
  @override
  Stream<Exercise?> build(String id) {
    return ref.watch(exerciseRepositoryProvider).watchExercise(id);
  }

  /// Deletes the custom exercise via the API then removes it from the local
  /// cache. Throws on failure so callers can surface an error message.
  Future<void> delete() async {
    await ref.read(exerciseRepositoryProvider).deleteCustomExercise(id);
  }
}
