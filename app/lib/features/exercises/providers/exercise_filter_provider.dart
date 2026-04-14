import 'package:fitness_data/fitness_data.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'exercise_filter_provider.freezed.dart';
part 'exercise_filter_provider.g.dart';

@freezed
abstract class ExerciseFilterState with _$ExerciseFilterState {
  const factory ExerciseFilterState({
    @Default('') String search,
    ExerciseType? type,
    String? muscleGroupName,
  }) = _ExerciseFilterState;
}

@riverpod
class ExerciseFilter extends _$ExerciseFilter {
  @override
  ExerciseFilterState build() => const ExerciseFilterState();

  void setSearch(String query) =>
      state = state.copyWith(search: query);

  void setType(ExerciseType? type) =>
      state = state.copyWith(type: type);

  void setMuscleGroup(String? name) =>
      state = state.copyWith(muscleGroupName: name);

  void clearAll() => state = const ExerciseFilterState();
}
