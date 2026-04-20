import 'package:fitness_domain/fitness_domain.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import 'exercise_providers.dart';

part 'exercise_form_provider.freezed.dart';
part 'exercise_form_provider.g.dart';

@freezed
abstract class ExerciseFormState with _$ExerciseFormState {
  const factory ExerciseFormState({
    @Default('') String name,
    @Default('') String description,
    @Default(ExerciseType.strength) ExerciseType exerciseType,
    @Default('') String instructions,
    @Default([]) List<({String muscleGroupId, String displayName, bool isPrimary})> selectedMuscleGroups,
    @Default(false) bool isLoading,
    AppException? error,
    @Default(false) bool submitted,
  }) = _ExerciseFormState;
}

@riverpod
class ExerciseForm extends _$ExerciseForm {
  @override
  ExerciseFormState build() => const ExerciseFormState();

  void setName(String value) =>
      state = state.copyWith(name: value, error: null);
  void setDescription(String value) =>
      state = state.copyWith(description: value);
  void setExerciseType(ExerciseType value) =>
      state = state.copyWith(exerciseType: value);
  void setInstructions(String value) =>
      state = state.copyWith(instructions: value);

  /// Toggles a muscle group selection with correct primary-muscle semantics:
  ///
  /// - Not selected → add as primary (if no primary exists yet) or secondary.
  /// - Selected & non-primary → promote to primary (demote current primary).
  /// - Selected & primary → deselect; next group in list becomes primary.
  void toggleMuscleGroup({
    required String muscleGroupId,
    required String displayName,
  }) {
    final current = state.selectedMuscleGroups;
    final existing =
        current.where((m) => m.muscleGroupId == muscleGroupId).firstOrNull;

    if (existing == null) {
      // Not yet selected: add as primary if no primary exists, else secondary.
      final noPrimary = !current.any((m) => m.isPrimary);
      state = state.copyWith(
        selectedMuscleGroups: [
          ...current,
          (
            muscleGroupId: muscleGroupId,
            displayName: displayName,
            isPrimary: noPrimary,
          ),
        ],
      );
    } else if (!existing.isPrimary) {
      // Selected but non-primary: promote to primary, demote current primary.
      state = state.copyWith(
        selectedMuscleGroups: current.map((m) {
          if (m.muscleGroupId == muscleGroupId) {
            return (
              muscleGroupId: m.muscleGroupId,
              displayName: m.displayName,
              isPrimary: true,
            );
          }
          return (
            muscleGroupId: m.muscleGroupId,
            displayName: m.displayName,
            isPrimary: false,
          );
        }).toList(),
      );
    } else {
      // Selected & primary: deselect. Promote the first remaining group.
      final remaining =
          current.where((m) => m.muscleGroupId != muscleGroupId).toList();
      final updated = remaining.isEmpty || remaining.first.isPrimary
          ? remaining
          : [
              (
                muscleGroupId: remaining.first.muscleGroupId,
                displayName: remaining.first.displayName,
                isPrimary: true,
              ),
              ...remaining.skip(1),
            ];
      state = state.copyWith(selectedMuscleGroups: updated);
    }
  }

  Future<void> submit() async {
    if (state.name.trim().isEmpty) {
      state = state.copyWith(
        error: const AppException.validation(
          message: 'Exercise name is required.',
        ),
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(exerciseRepositoryProvider).createCustomExercise(
            name: state.name.trim(),
            description: state.description.trim().isEmpty
                ? null
                : state.description.trim(),
            exerciseType: state.exerciseType,
            instructions: state.instructions.trim().isEmpty
                ? null
                : state.instructions.trim(),
            muscleGroups: state.selectedMuscleGroups
                .map(
                  (m) => (
                    muscleGroupId: m.muscleGroupId,
                    isPrimary: m.isPrimary,
                  ),
                )
                .toList(),
          );
      state = state.copyWith(isLoading: false, submitted: true);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: AppException.unknown(message: e.toString()),
      );
    }
  }
}
