import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_dtos.freezed.dart';
part 'sync_dtos.g.dart';

// ─── Push request ─────────────────────────────────────────────────────────────

@freezed
abstract class SyncPushItemDto with _$SyncPushItemDto {
  const factory SyncPushItemDto({
    required String id,
    required String entityTable,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) = _SyncPushItemDto;

  factory SyncPushItemDto.fromJson(Map<String, dynamic> json) =>
      _$SyncPushItemDtoFromJson(json);
}

@freezed
abstract class SyncPushRequestDto with _$SyncPushRequestDto {
  const factory SyncPushRequestDto({
    required List<SyncPushItemDto> items,
  }) = _SyncPushRequestDto;

  factory SyncPushRequestDto.fromJson(Map<String, dynamic> json) =>
      _$SyncPushRequestDtoFromJson(json);
}

// ─── Push response ────────────────────────────────────────────────────────────

@freezed
abstract class SyncItemResultDto with _$SyncItemResultDto {
  const factory SyncItemResultDto({
    required String id,
    required String status,
    String? error,
  }) = _SyncItemResultDto;

  factory SyncItemResultDto.fromJson(Map<String, dynamic> json) =>
      _$SyncItemResultDtoFromJson(json);
}

@freezed
abstract class SyncPushDataDto with _$SyncPushDataDto {
  const factory SyncPushDataDto({
    required List<SyncItemResultDto> results,
  }) = _SyncPushDataDto;

  factory SyncPushDataDto.fromJson(Map<String, dynamic> json) =>
      _$SyncPushDataDtoFromJson(json);
}

@freezed
abstract class SyncPushEnvelopeDto with _$SyncPushEnvelopeDto {
  const factory SyncPushEnvelopeDto({
    required int status,
    required SyncPushDataDto data,
  }) = _SyncPushEnvelopeDto;

  factory SyncPushEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$SyncPushEnvelopeDtoFromJson(json);
}

// ─── Pull response — flat entity DTOs ────────────────────────────────────────

@freezed
abstract class SyncSessionDto with _$SyncSessionDto {
  const factory SyncSessionDto({
    required String id,
    String? planId,
    String? planDayId,
    required String startedAt,
    String? completedAt,
    int? durationSec,
    String? notes,
    required String status,
    required String createdAt,
    required String updatedAt,
  }) = _SyncSessionDto;

  factory SyncSessionDto.fromJson(Map<String, dynamic> json) =>
      _$SyncSessionDtoFromJson(json);
}

@freezed
abstract class SyncExerciseLogDto with _$SyncExerciseLogDto {
  const factory SyncExerciseLogDto({
    required String id,
    required String sessionId,
    required String exerciseId,
    required int sortOrder,
    String? notes,
    required String createdAt,
    required String updatedAt,
  }) = _SyncExerciseLogDto;

  factory SyncExerciseLogDto.fromJson(Map<String, dynamic> json) =>
      _$SyncExerciseLogDtoFromJson(json);
}

@freezed
abstract class SyncSetLogDto with _$SyncSetLogDto {
  const factory SyncSetLogDto({
    required String id,
    required String exerciseLogId,
    required int setNumber,
    int? reps,
    double? weightKg,
    int? durationSec,
    double? distanceM,
    double? paceSecPerKm,
    int? heartRate,
    int? rpe,
    String? tempo,
    @Default(false) bool isWarmup,
    String? completedAt,
    required String createdAt,
    required String updatedAt,
  }) = _SyncSetLogDto;

  factory SyncSetLogDto.fromJson(Map<String, dynamic> json) =>
      _$SyncSetLogDtoFromJson(json);
}

@freezed
abstract class SyncPlanDto with _$SyncPlanDto {
  const factory SyncPlanDto({
    required String id,
    required String name,
    String? description,
    required bool isActive,
    required String scheduleType,
    int? weeksCount,
    required String createdAt,
    required String updatedAt,
  }) = _SyncPlanDto;

  factory SyncPlanDto.fromJson(Map<String, dynamic> json) =>
      _$SyncPlanDtoFromJson(json);
}

@freezed
abstract class SyncPlanDayDto with _$SyncPlanDayDto {
  const factory SyncPlanDayDto({
    required String id,
    required String planId,
    required int dayOfWeek,
    int? weekNumber,
    String? name,
    required int sortOrder,
    required String createdAt,
    required String updatedAt,
  }) = _SyncPlanDayDto;

  factory SyncPlanDayDto.fromJson(Map<String, dynamic> json) =>
      _$SyncPlanDayDtoFromJson(json);
}

@freezed
abstract class SyncPlanDayExerciseDto with _$SyncPlanDayExerciseDto {
  const factory SyncPlanDayExerciseDto({
    required String id,
    required String planDayId,
    required String exerciseId,
    required int sortOrder,
    int? targetSets,
    String? targetReps,
    int? targetDurationSec,
    double? targetDistanceM,
    String? notes,
    required String createdAt,
    required String updatedAt,
  }) = _SyncPlanDayExerciseDto;

  factory SyncPlanDayExerciseDto.fromJson(Map<String, dynamic> json) =>
      _$SyncPlanDayExerciseDtoFromJson(json);
}

// ─── Pull envelope ────────────────────────────────────────────────────────────

@freezed
abstract class SyncPullDataDto with _$SyncPullDataDto {
  const factory SyncPullDataDto({
    @Default([]) List<SyncSessionDto> sessions,
    @Default([]) List<SyncExerciseLogDto> exerciseLogs,
    @Default([]) List<SyncSetLogDto> setLogs,
    @Default([]) List<SyncPlanDto> plans,
    @Default([]) List<SyncPlanDayDto> planDays,
    @Default([]) List<SyncPlanDayExerciseDto> planDayExercises,
    required String syncedAt,
  }) = _SyncPullDataDto;

  factory SyncPullDataDto.fromJson(Map<String, dynamic> json) =>
      _$SyncPullDataDtoFromJson(json);
}

@freezed
abstract class SyncPullEnvelopeDto with _$SyncPullEnvelopeDto {
  const factory SyncPullEnvelopeDto({
    required int status,
    required SyncPullDataDto data,
  }) = _SyncPullEnvelopeDto;

  factory SyncPullEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$SyncPullEnvelopeDtoFromJson(json);
}
