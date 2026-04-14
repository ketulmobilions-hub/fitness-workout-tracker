import 'package:freezed_annotation/freezed_annotation.dart';

part 'muscle_group.freezed.dart';

@freezed
abstract class MuscleGroup with _$MuscleGroup {
  const factory MuscleGroup({
    required String id,
    required String name,
    required String displayName,
    required String bodyRegion,
    @Default(false) bool isPrimary,
  }) = _MuscleGroup;
}
