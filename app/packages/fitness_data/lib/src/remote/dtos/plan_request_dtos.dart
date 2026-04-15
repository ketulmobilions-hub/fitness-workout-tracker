import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan_request_dtos.freezed.dart';
part 'plan_request_dtos.g.dart';

// ---------------------------------------------------------------------------
// Create plan
// ---------------------------------------------------------------------------

@freezed
abstract class CreatePlanDayDto with _$CreatePlanDayDto {
  const factory CreatePlanDayDto({
    required int dayOfWeek,
    @JsonKey(includeIfNull: false) int? weekNumber,
    @JsonKey(includeIfNull: false) String? name,
    required int sortOrder,
  }) = _CreatePlanDayDto;

  factory CreatePlanDayDto.fromJson(Map<String, dynamic> json) =>
      _$CreatePlanDayDtoFromJson(json);
}

@freezed
abstract class CreatePlanRequestDto with _$CreatePlanRequestDto {
  const factory CreatePlanRequestDto({
    required String name,
    @JsonKey(includeIfNull: false) String? description,
    required String scheduleType,
    @JsonKey(includeIfNull: false) int? weeksCount,
    @JsonKey(includeIfNull: false) List<CreatePlanDayDto>? days,
  }) = _CreatePlanRequestDto;

  factory CreatePlanRequestDto.fromJson(Map<String, dynamic> json) =>
      _$CreatePlanRequestDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Update plan (all fields optional — at least one required by the server)
// ---------------------------------------------------------------------------

@freezed
abstract class UpdatePlanRequestDto with _$UpdatePlanRequestDto {
  const factory UpdatePlanRequestDto({
    @JsonKey(includeIfNull: false) String? name,
    @JsonKey(includeIfNull: false) String? description,
    @JsonKey(includeIfNull: false) String? scheduleType,
    @JsonKey(includeIfNull: false) int? weeksCount,
    @JsonKey(includeIfNull: false) bool? isActive,
  }) = _UpdatePlanRequestDto;

  factory UpdatePlanRequestDto.fromJson(Map<String, dynamic> json) =>
      _$UpdatePlanRequestDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Add exercise to a plan day
// ---------------------------------------------------------------------------

@freezed
abstract class AddPlanExerciseRequestDto with _$AddPlanExerciseRequestDto {
  const factory AddPlanExerciseRequestDto({
    required String planDayId,
    required String exerciseId,
    required int sortOrder,
    @JsonKey(includeIfNull: false) int? targetSets,
    @JsonKey(includeIfNull: false) String? targetReps,
    @JsonKey(includeIfNull: false) int? targetDurationSec,
    @JsonKey(includeIfNull: false) double? targetDistanceM,
    @JsonKey(includeIfNull: false) String? notes,
  }) = _AddPlanExerciseRequestDto;

  factory AddPlanExerciseRequestDto.fromJson(Map<String, dynamic> json) =>
      _$AddPlanExerciseRequestDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Update exercise targets (all optional — at least one required by the server)
// ---------------------------------------------------------------------------

@freezed
abstract class UpdatePlanExerciseRequestDto
    with _$UpdatePlanExerciseRequestDto {
  const factory UpdatePlanExerciseRequestDto({
    @JsonKey(includeIfNull: false) int? sortOrder,
    @JsonKey(includeIfNull: false) int? targetSets,
    @JsonKey(includeIfNull: false) String? targetReps,
    @JsonKey(includeIfNull: false) int? targetDurationSec,
    @JsonKey(includeIfNull: false) double? targetDistanceM,
    // notes can be explicitly set to null to clear the field — use
    // includeIfNull: true here so a null notes IS sent over the wire.
    String? notes,
  }) = _UpdatePlanExerciseRequestDto;

  factory UpdatePlanExerciseRequestDto.fromJson(Map<String, dynamic> json) =>
      _$UpdatePlanExerciseRequestDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Reorder exercises within a plan day
// ---------------------------------------------------------------------------

@freezed
abstract class ReorderPlanExercisesRequestDto
    with _$ReorderPlanExercisesRequestDto {
  const factory ReorderPlanExercisesRequestDto({
    required String planDayId,
    // Server schema key is planDayExerciseIds — must match exactly.
    required List<String> planDayExerciseIds,
  }) = _ReorderPlanExercisesRequestDto;

  factory ReorderPlanExercisesRequestDto.fromJson(
          Map<String, dynamic> json) =>
      _$ReorderPlanExercisesRequestDtoFromJson(json);
}
