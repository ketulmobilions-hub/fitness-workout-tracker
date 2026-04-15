import 'package:fitness_domain/fitness_domain.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../exercises/providers/exercise_providers.dart';

part 'exercise_picker_filter_provider.freezed.dart';
part 'exercise_picker_filter_provider.g.dart';

/// Filter state for the exercise picker inside the plan form.
///
/// This is an isolated copy of [ExerciseFilterState] so that searching inside
/// the picker does not mutate the global [exerciseFilterProvider] used by the
/// main exercise list screen.
@freezed
abstract class ExercisePickerFilterState with _$ExercisePickerFilterState {
  const factory ExercisePickerFilterState({
    @Default('') String search,
    ExerciseType? type,
    String? muscleGroupName,
  }) = _ExercisePickerFilterState;
}

@riverpod
class ExercisePickerFilter extends _$ExercisePickerFilter {
  @override
  ExercisePickerFilterState build() => const ExercisePickerFilterState();

  void setSearch(String query) =>
      state = state.copyWith(search: query);

  void setType(ExerciseType? type) =>
      state = state.copyWith(type: type);

  void setMuscleGroup(String? name) =>
      state = state.copyWith(muscleGroupName: name);

  void clearAll() => state = const ExercisePickerFilterState();
}

/// Filtered exercise stream for the picker — routes through the repository
/// (business-logic layer) so the presentation layer never touches data directly.
@riverpod
Stream<List<Exercise>> exercisePickerList(Ref ref) {
  final filter = ref.watch(exercisePickerFilterProvider);
  return ref.watch(exerciseRepositoryProvider).watchExercises(
        search: filter.search.isEmpty ? null : filter.search,
        type: filter.type,
        muscleGroupName: filter.muscleGroupName,
      );
}
