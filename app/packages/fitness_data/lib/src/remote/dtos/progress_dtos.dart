import 'package:freezed_annotation/freezed_annotation.dart';

part 'progress_dtos.freezed.dart';
part 'progress_dtos.g.dart';

// ---------------------------------------------------------------------------
// Overview DTO
// ---------------------------------------------------------------------------

@freezed
abstract class ProgressOverviewDto with _$ProgressOverviewDto {
  const factory ProgressOverviewDto({
    required int totalWorkouts,
    required double volumeThisWeek,
    required double volumeThisMonth,
    required int currentStreak,
    required int longestStreak,
    String? lastWorkoutDate,
    @Default(null) double? wilks,
    @Default(null) double? dots,
    @Default(null) double? ipfGl,
  }) = _ProgressOverviewDto;

  factory ProgressOverviewDto.fromJson(Map<String, dynamic> json) =>
      _$ProgressOverviewDtoFromJson(json);
}

@freezed
abstract class ProgressOverviewEnvelopeDto with _$ProgressOverviewEnvelopeDto {
  const factory ProgressOverviewEnvelopeDto({
    required int status,
    required ProgressOverviewDto data,
  }) = _ProgressOverviewEnvelopeDto;

  factory ProgressOverviewEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$ProgressOverviewEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Exercise progress DTOs
// ---------------------------------------------------------------------------

@freezed
abstract class ExerciseInfoDto with _$ExerciseInfoDto {
  const factory ExerciseInfoDto({
    required String id,
    required String name,
    required String type,
  }) = _ExerciseInfoDto;

  factory ExerciseInfoDto.fromJson(Map<String, dynamic> json) =>
      _$ExerciseInfoDtoFromJson(json);
}

@freezed
abstract class ExercisePersonalRecordsDto with _$ExercisePersonalRecordsDto {
  const factory ExercisePersonalRecordsDto({
    double? maxWeight,
    double? maxReps,
    double? maxVolume,
    double? bestPace,
  }) = _ExercisePersonalRecordsDto;

  factory ExercisePersonalRecordsDto.fromJson(Map<String, dynamic> json) =>
      _$ExercisePersonalRecordsDtoFromJson(json);
}

@freezed
abstract class ExerciseHistoryPointDto with _$ExerciseHistoryPointDto {
  const factory ExerciseHistoryPointDto({
    required String date,
    double? maxWeight,
    required double totalVolume,
    required int totalReps,
    required int setsCount,
  }) = _ExerciseHistoryPointDto;

  factory ExerciseHistoryPointDto.fromJson(Map<String, dynamic> json) =>
      _$ExerciseHistoryPointDtoFromJson(json);
}

@freezed
abstract class ExerciseProgressDto with _$ExerciseProgressDto {
  const factory ExerciseProgressDto({
    required ExerciseInfoDto exercise,
    required ExercisePersonalRecordsDto personalRecords,
    double? estimatedOneRepMax,
    @Default([]) List<ExerciseHistoryPointDto> history,
  }) = _ExerciseProgressDto;

  factory ExerciseProgressDto.fromJson(Map<String, dynamic> json) =>
      _$ExerciseProgressDtoFromJson(json);
}

@freezed
abstract class ExerciseProgressEnvelopeDto with _$ExerciseProgressEnvelopeDto {
  const factory ExerciseProgressEnvelopeDto({
    required int status,
    required ExerciseProgressDto data,
  }) = _ExerciseProgressEnvelopeDto;

  factory ExerciseProgressEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$ExerciseProgressEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Personal records DTOs
// ---------------------------------------------------------------------------

@freezed
abstract class ProgressPersonalRecordExerciseDto
    with _$ProgressPersonalRecordExerciseDto {
  const factory ProgressPersonalRecordExerciseDto({
    required String id,
    required String name,
  }) = _ProgressPersonalRecordExerciseDto;

  factory ProgressPersonalRecordExerciseDto.fromJson(
          Map<String, dynamic> json) =>
      _$ProgressPersonalRecordExerciseDtoFromJson(json);
}

@freezed
abstract class ProgressPersonalRecordDto with _$ProgressPersonalRecordDto {
  const factory ProgressPersonalRecordDto({
    required String id,
    required ProgressPersonalRecordExerciseDto exercise,
    required String recordType,
    required double value,
    required String achievedAt,
    String? sessionId,
  }) = _ProgressPersonalRecordDto;

  factory ProgressPersonalRecordDto.fromJson(Map<String, dynamic> json) =>
      _$ProgressPersonalRecordDtoFromJson(json);
}

@freezed
abstract class PersonalRecordsDataDto with _$PersonalRecordsDataDto {
  const factory PersonalRecordsDataDto({
    @Default([]) List<ProgressPersonalRecordDto> data,
  }) = _PersonalRecordsDataDto;

  factory PersonalRecordsDataDto.fromJson(Map<String, dynamic> json) =>
      _$PersonalRecordsDataDtoFromJson(json);
}

@freezed
abstract class PersonalRecordsEnvelopeDto with _$PersonalRecordsEnvelopeDto {
  const factory PersonalRecordsEnvelopeDto({
    required int status,
    required PersonalRecordsDataDto data,
  }) = _PersonalRecordsEnvelopeDto;

  factory PersonalRecordsEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$PersonalRecordsEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// SBD total DTOs
// ---------------------------------------------------------------------------

@freezed
abstract class SbdMonthPointDto with _$SbdMonthPointDto {
  const factory SbdMonthPointDto({
    required String month,
    required double squat,
    required double bench,
    required double deadlift,
  }) = _SbdMonthPointDto;

  factory SbdMonthPointDto.fromJson(Map<String, dynamic> json) =>
      _$SbdMonthPointDtoFromJson(json);
}

// Fix #7: nullable fields on a DTO don't need @Default(null) — Dart null safety
// already defaults them to null. Removed to match the pattern used by other DTOs
// in this file (e.g. ProgressOverviewDto.wilks).
@freezed
abstract class SbdTotalDto with _$SbdTotalDto {
  const factory SbdTotalDto({
    double? squat,
    double? bench,
    double? deadlift,
    double? total,
    @Default(0) int liftCount,
    @Default([]) List<SbdMonthPointDto> monthly,
    double? monthOverMonthDelta,
    String? deltaVsMonth,
  }) = _SbdTotalDto;

  factory SbdTotalDto.fromJson(Map<String, dynamic> json) =>
      _$SbdTotalDtoFromJson(json);
}

@freezed
abstract class SbdTotalEnvelopeDto with _$SbdTotalEnvelopeDto {
  const factory SbdTotalEnvelopeDto({
    required int status,
    required SbdTotalDto data,
  }) = _SbdTotalEnvelopeDto;

  factory SbdTotalEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$SbdTotalEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Strength score history DTOs
// ---------------------------------------------------------------------------

@freezed
abstract class ScoreHistoryPointDto with _$ScoreHistoryPointDto {
  const factory ScoreHistoryPointDto({
    required String month,
    @Default(null) double? wilks,
    @Default(null) double? dots,
    @Default(null) double? ipfGl,
  }) = _ScoreHistoryPointDto;

  factory ScoreHistoryPointDto.fromJson(Map<String, dynamic> json) =>
      _$ScoreHistoryPointDtoFromJson(json);
}

// Server sends sendSuccess(res, points) — data field is the array directly.
@freezed
abstract class ScoreHistoryEnvelopeDto with _$ScoreHistoryEnvelopeDto {
  const factory ScoreHistoryEnvelopeDto({
    required int status,
    @Default([]) List<ScoreHistoryPointDto> data,
  }) = _ScoreHistoryEnvelopeDto;

  factory ScoreHistoryEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$ScoreHistoryEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Volume zone DTOs
// ---------------------------------------------------------------------------

@freezed
abstract class VolumeZoneWeekDto with _$VolumeZoneWeekDto {
  const factory VolumeZoneWeekDto({
    required String weekStart,
    required bool isDeload,
    required int techniqueSets,
    required double techniqueTonnageKg,
    required int hypertrophySets,
    required double hypertrophyTonnageKg,
    required int strengthSets,
    required double strengthTonnageKg,
    required int maxEffortSets,
    required double maxEffortTonnageKg,
  }) = _VolumeZoneWeekDto;

  factory VolumeZoneWeekDto.fromJson(Map<String, dynamic> json) =>
      _$VolumeZoneWeekDtoFromJson(json);
}

@freezed
abstract class VolumeZoneAnalysisDto with _$VolumeZoneAnalysisDto {
  const factory VolumeZoneAnalysisDto({
    required int weeks,
    @Default([]) List<VolumeZoneWeekDto> data,
  }) = _VolumeZoneAnalysisDto;

  factory VolumeZoneAnalysisDto.fromJson(Map<String, dynamic> json) =>
      _$VolumeZoneAnalysisDtoFromJson(json);
}

@freezed
abstract class VolumeZoneEnvelopeDto with _$VolumeZoneEnvelopeDto {
  const factory VolumeZoneEnvelopeDto({
    required int status,
    required VolumeZoneAnalysisDto data,
  }) = _VolumeZoneEnvelopeDto;

  factory VolumeZoneEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$VolumeZoneEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Volume DTOs
// ---------------------------------------------------------------------------

@freezed
abstract class VolumeBucketDto with _$VolumeBucketDto {
  const factory VolumeBucketDto({
    required String date,
    required double volume,
    required int sessions,
  }) = _VolumeBucketDto;

  factory VolumeBucketDto.fromJson(Map<String, dynamic> json) =>
      _$VolumeBucketDtoFromJson(json);
}

@freezed
abstract class VolumeDataDto with _$VolumeDataDto {
  const factory VolumeDataDto({
    required String granularity,
    @Default([]) List<VolumeBucketDto> data,
  }) = _VolumeDataDto;

  factory VolumeDataDto.fromJson(Map<String, dynamic> json) =>
      _$VolumeDataDtoFromJson(json);
}

@freezed
abstract class VolumeEnvelopeDto with _$VolumeEnvelopeDto {
  const factory VolumeEnvelopeDto({
    required int status,
    required VolumeDataDto data,
  }) = _VolumeEnvelopeDto;

  factory VolumeEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$VolumeEnvelopeDtoFromJson(json);
}
