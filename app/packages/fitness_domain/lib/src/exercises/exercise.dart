import 'package:freezed_annotation/freezed_annotation.dart';

import 'exercise_type.dart';
import 'muscle_group.dart';

part 'exercise.freezed.dart';

@freezed
abstract class Exercise with _$Exercise {
  const factory Exercise({
    required String id,
    required String name,
    String? description,
    required ExerciseType exerciseType,
    String? instructions,
    String? mediaUrl,
    required bool isCustom,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default([]) List<MuscleGroup> muscleGroups,
  }) = _Exercise;
}
