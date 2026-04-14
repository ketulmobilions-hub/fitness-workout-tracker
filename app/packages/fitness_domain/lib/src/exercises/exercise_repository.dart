import 'exercise.dart';
import 'exercise_type.dart';
import 'muscle_group.dart';

abstract class ExerciseRepository {
  /// Stream of exercises filtered by optional [search] text, [type], and
  /// [muscleGroupName]. All filters are ANDed. Pass null to omit a filter.
  Stream<List<Exercise>> watchExercises({
    String? search,
    ExerciseType? type,
    String? muscleGroupName,
  });

  /// Stream of a single exercise with its muscle groups populated.
  /// Emits null when no exercise with [id] exists in the local cache.
  Stream<Exercise?> watchExercise(String id);

  /// Reactive stream of all cached muscle groups, ordered by body region then
  /// display name. Used to populate filter chips and the create-exercise form.
  Stream<List<MuscleGroup>> watchMuscleGroups();

  /// Fetches all exercises and muscle groups from the API and upserts them into
  /// the local Drift database. All writes are wrapped in a single transaction
  /// so a mid-sync interruption cannot leave the DB in a partial state.
  Future<void> syncExercises();

  /// Returns all muscle groups from the local cache.
  Future<List<MuscleGroup>> getMuscleGroups();

  /// Creates a new custom exercise via the API and caches the result locally.
  Future<Exercise> createCustomExercise({
    required String name,
    String? description,
    required ExerciseType exerciseType,
    String? instructions,
    String? mediaUrl,
    required List<({String muscleGroupId, bool isPrimary})> muscleGroups,
  });

  /// Deletes a custom exercise via the API, then removes it from the local
  /// cache. On crash between the two operations, the next [syncExercises] call
  /// cleans up any orphaned system exercises.
  Future<void> deleteCustomExercise(String id);
}
