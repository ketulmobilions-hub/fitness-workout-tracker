import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_dtos.freezed.dart';
part 'exercise_dtos.g.dart';

// ---------------------------------------------------------------------------
// Shared sub-objects
// ---------------------------------------------------------------------------

@freezed
abstract class MuscleGroupDto with _$MuscleGroupDto {
  const factory MuscleGroupDto({
    required String id,
    required String name,
    required String displayName,
    required String bodyRegion,
  }) = _MuscleGroupDto;

  factory MuscleGroupDto.fromJson(Map<String, dynamic> json) =>
      _$MuscleGroupDtoFromJson(json);
}

@freezed
abstract class ExerciseMuscleGroupDto with _$ExerciseMuscleGroupDto {
  const factory ExerciseMuscleGroupDto({
    required String id,
    required String name,
    required String displayName,
    required String bodyRegion,
    required bool isPrimary,
  }) = _ExerciseMuscleGroupDto;

  factory ExerciseMuscleGroupDto.fromJson(Map<String, dynamic> json) =>
      _$ExerciseMuscleGroupDtoFromJson(json);
}

@freezed
abstract class PaginationDto with _$PaginationDto {
  const factory PaginationDto({
    @JsonKey(name: 'next_cursor') String? nextCursor,
    @JsonKey(name: 'has_more') required bool hasMore,
    required int limit,
  }) = _PaginationDto;

  factory PaginationDto.fromJson(Map<String, dynamic> json) =>
      _$PaginationDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Exercise DTO (returned in list and detail responses)
// ---------------------------------------------------------------------------

@freezed
abstract class ExerciseDto with _$ExerciseDto {
  const factory ExerciseDto({
    required String id,
    required String name,
    String? description,
    required String exerciseType,
    String? instructions,
    String? mediaUrl,
    required bool isCustom,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default([]) List<ExerciseMuscleGroupDto> muscleGroups,
  }) = _ExerciseDto;

  factory ExerciseDto.fromJson(Map<String, dynamic> json) =>
      _$ExerciseDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// List endpoint envelope: { "status": 200, "data": { "exercises": [...], "pagination": {...} } }
// ---------------------------------------------------------------------------

@freezed
abstract class ExerciseListDataDto with _$ExerciseListDataDto {
  const factory ExerciseListDataDto({
    required List<ExerciseDto> exercises,
    required PaginationDto pagination,
  }) = _ExerciseListDataDto;

  factory ExerciseListDataDto.fromJson(Map<String, dynamic> json) =>
      _$ExerciseListDataDtoFromJson(json);
}

@freezed
abstract class ExerciseListEnvelopeDto with _$ExerciseListEnvelopeDto {
  const factory ExerciseListEnvelopeDto({
    required int status,
    required ExerciseListDataDto data,
  }) = _ExerciseListEnvelopeDto;

  factory ExerciseListEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$ExerciseListEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Detail endpoint envelope: { "status": 200, "data": { "exercise": {...} } }
// ---------------------------------------------------------------------------

@freezed
abstract class ExerciseDetailDataDto with _$ExerciseDetailDataDto {
  const factory ExerciseDetailDataDto({
    required ExerciseDto exercise,
  }) = _ExerciseDetailDataDto;

  factory ExerciseDetailDataDto.fromJson(Map<String, dynamic> json) =>
      _$ExerciseDetailDataDtoFromJson(json);
}

@freezed
abstract class ExerciseDetailEnvelopeDto with _$ExerciseDetailEnvelopeDto {
  const factory ExerciseDetailEnvelopeDto({
    required int status,
    required ExerciseDetailDataDto data,
  }) = _ExerciseDetailEnvelopeDto;

  factory ExerciseDetailEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$ExerciseDetailEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Muscle groups list envelope: { "status": 200, "data": { "muscleGroups": [...] } }
// ---------------------------------------------------------------------------

@freezed
abstract class MuscleGroupListDataDto with _$MuscleGroupListDataDto {
  const factory MuscleGroupListDataDto({
    required List<MuscleGroupDto> muscleGroups,
  }) = _MuscleGroupListDataDto;

  factory MuscleGroupListDataDto.fromJson(Map<String, dynamic> json) =>
      _$MuscleGroupListDataDtoFromJson(json);
}

@freezed
abstract class MuscleGroupListEnvelopeDto with _$MuscleGroupListEnvelopeDto {
  const factory MuscleGroupListEnvelopeDto({
    required int status,
    required MuscleGroupListDataDto data,
  }) = _MuscleGroupListEnvelopeDto;

  factory MuscleGroupListEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$MuscleGroupListEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Create / update request DTOs
// ---------------------------------------------------------------------------

@freezed
abstract class MuscleGroupReferenceDto with _$MuscleGroupReferenceDto {
  const factory MuscleGroupReferenceDto({
    required String muscleGroupId,
    required bool isPrimary,
  }) = _MuscleGroupReferenceDto;

  factory MuscleGroupReferenceDto.fromJson(Map<String, dynamic> json) =>
      _$MuscleGroupReferenceDtoFromJson(json);
}

@freezed
abstract class CreateExerciseRequestDto with _$CreateExerciseRequestDto {
  const factory CreateExerciseRequestDto({
    required String name,
    String? description,
    required String exerciseType,
    String? instructions,
    String? mediaUrl,
    @Default([]) List<MuscleGroupReferenceDto> muscleGroups,
  }) = _CreateExerciseRequestDto;

  factory CreateExerciseRequestDto.fromJson(Map<String, dynamic> json) =>
      _$CreateExerciseRequestDtoFromJson(json);
}
