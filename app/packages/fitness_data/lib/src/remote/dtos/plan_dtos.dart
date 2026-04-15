import 'package:freezed_annotation/freezed_annotation.dart';

import 'exercise_dtos.dart';

part 'plan_dtos.freezed.dart';
part 'plan_dtos.g.dart';

// ---------------------------------------------------------------------------
// Plan day exercise DTO
// ---------------------------------------------------------------------------

@freezed
abstract class PlanDayExerciseDto with _$PlanDayExerciseDto {
  const factory PlanDayExerciseDto({
    required String id,
    required String exerciseId,
    required String exerciseName,
    required String exerciseType,
    required int sortOrder,
    int? targetSets,
    String? targetReps,
    int? targetDurationSec,
    double? targetDistanceM,
    String? notes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _PlanDayExerciseDto;

  factory PlanDayExerciseDto.fromJson(Map<String, dynamic> json) =>
      _$PlanDayExerciseDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Plan day DTO
// ---------------------------------------------------------------------------

@freezed
abstract class PlanDayDto with _$PlanDayDto {
  const factory PlanDayDto({
    required String id,
    required int dayOfWeek,
    int? weekNumber,
    String? name,
    required int sortOrder,
    @Default([]) List<PlanDayExerciseDto> exercises,
  }) = _PlanDayDto;

  factory PlanDayDto.fromJson(Map<String, dynamic> json) =>
      _$PlanDayDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Plan DTO (used in both list and detail responses)
// ---------------------------------------------------------------------------

@freezed
abstract class PlanDto with _$PlanDto {
  const factory PlanDto({
    required String id,
    required String name,
    String? description,
    required bool isActive,
    required String scheduleType,
    int? weeksCount,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default([]) List<PlanDayDto> days,
  }) = _PlanDto;

  factory PlanDto.fromJson(Map<String, dynamic> json) =>
      _$PlanDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// List endpoint envelope: { "status": 200, "data": { "plans": [...], "pagination": {...} } }
// ---------------------------------------------------------------------------

@freezed
abstract class PlanListDataDto with _$PlanListDataDto {
  const factory PlanListDataDto({
    required List<PlanDto> plans,
    required PaginationDto pagination,
  }) = _PlanListDataDto;

  factory PlanListDataDto.fromJson(Map<String, dynamic> json) =>
      _$PlanListDataDtoFromJson(json);
}

@freezed
abstract class PlanListEnvelopeDto with _$PlanListEnvelopeDto {
  const factory PlanListEnvelopeDto({
    required int status,
    required PlanListDataDto data,
  }) = _PlanListEnvelopeDto;

  factory PlanListEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$PlanListEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Detail endpoint envelope: { "status": 200, "data": { "plan": {...} } }
// ---------------------------------------------------------------------------

@freezed
abstract class PlanDetailDataDto with _$PlanDetailDataDto {
  const factory PlanDetailDataDto({
    required PlanDto plan,
  }) = _PlanDetailDataDto;

  factory PlanDetailDataDto.fromJson(Map<String, dynamic> json) =>
      _$PlanDetailDataDtoFromJson(json);
}

@freezed
abstract class PlanDetailEnvelopeDto with _$PlanDetailEnvelopeDto {
  const factory PlanDetailEnvelopeDto({
    required int status,
    required PlanDetailDataDto data,
  }) = _PlanDetailEnvelopeDto;

  factory PlanDetailEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$PlanDetailEnvelopeDtoFromJson(json);
}
