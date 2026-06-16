import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_dtos.freezed.dart';
part 'session_dtos.g.dart';

// ---------------------------------------------------------------------------
// Set log DTO
// ---------------------------------------------------------------------------

@freezed
abstract class SetLogDto with _$SetLogDto {
  const factory SetLogDto({
    required String id,
    required int setNumber,
    int? reps,
    double? weightKg,
    int? durationSec,
    double? distanceM,
    double? paceSecPerKm,
    int? heartRate,
    double? rpe,
    String? tempo,
    @Default(false) bool isWarmup,
    String? completedAt,
    required String createdAt,
    required String updatedAt,
  }) = _SetLogDto;

  factory SetLogDto.fromJson(Map<String, dynamic> json) =>
      _$SetLogDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Exercise log DTO
// ---------------------------------------------------------------------------

@freezed
abstract class ExerciseLogDto with _$ExerciseLogDto {
  const factory ExerciseLogDto({
    required String id,
    required String exerciseId,
    required String exerciseName,
    required String exerciseType,
    required int sortOrder,
    String? notes,
    @Default([]) List<SetLogDto> sets,
  }) = _ExerciseLogDto;

  factory ExerciseLogDto.fromJson(Map<String, dynamic> json) =>
      _$ExerciseLogDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Session DTO (full detail with exercise logs)
// ---------------------------------------------------------------------------

@freezed
abstract class SessionDetailDto with _$SessionDetailDto {
  const factory SessionDetailDto({
    required String id,
    String? planId,
    String? planDayId,
    required String status,
    required String startedAt,
    String? completedAt,
    int? durationSec,
    String? notes,
    @Default([]) List<ExerciseLogDto> exercises,
    required String createdAt,
    required String updatedAt,
  }) = _SessionDetailDto;

  factory SessionDetailDto.fromJson(Map<String, dynamic> json) =>
      _$SessionDetailDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Start session response: { "status": 201, "data": { "session": {...}, "suggestedWeights": {...} } }
// ---------------------------------------------------------------------------

@freezed
abstract class StartSessionDataDto with _$StartSessionDataDto {
  const factory StartSessionDataDto({
    required SessionDetailDto session,
    // exerciseId → suggested weight in kg (PR × targetWeightPct1rm exercises only).
    // RPE-based suggestions are lazy-loaded via GET /sessions/suggest-weight per exercise.
    @Default(<String, double>{}) Map<String, double> suggestedWeights,
  }) = _StartSessionDataDto;

  factory StartSessionDataDto.fromJson(Map<String, dynamic> json) =>
      _$StartSessionDataDtoFromJson(json);
}

@freezed
abstract class StartSessionEnvelopeDto with _$StartSessionEnvelopeDto {
  const factory StartSessionEnvelopeDto({
    required int status,
    required StartSessionDataDto data,
  }) = _StartSessionEnvelopeDto;

  factory StartSessionEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$StartSessionEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Session detail envelope: { "status": 200, "data": { "session": {...} } }
// ---------------------------------------------------------------------------

@freezed
abstract class SessionDetailDataDto with _$SessionDetailDataDto {
  const factory SessionDetailDataDto({
    required SessionDetailDto session,
  }) = _SessionDetailDataDto;

  factory SessionDetailDataDto.fromJson(Map<String, dynamic> json) =>
      _$SessionDetailDataDtoFromJson(json);
}

@freezed
abstract class SessionDetailEnvelopeDto with _$SessionDetailEnvelopeDto {
  const factory SessionDetailEnvelopeDto({
    required int status,
    required SessionDetailDataDto data,
  }) = _SessionDetailEnvelopeDto;

  factory SessionDetailEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$SessionDetailEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Log set response: { "status": 201, "data": { "set": {...} } }
// ---------------------------------------------------------------------------

@freezed
abstract class LogSetDataDto with _$LogSetDataDto {
  const factory LogSetDataDto({
    required SetLogDto set,
  }) = _LogSetDataDto;

  factory LogSetDataDto.fromJson(Map<String, dynamic> json) =>
      _$LogSetDataDtoFromJson(json);
}

@freezed
abstract class LogSetEnvelopeDto with _$LogSetEnvelopeDto {
  const factory LogSetEnvelopeDto({
    required int status,
    required LogSetDataDto data,
  }) = _LogSetEnvelopeDto;

  factory LogSetEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$LogSetEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// New personal record DTO (returned on session completion)
// ---------------------------------------------------------------------------

@freezed
abstract class NewPersonalRecordDto with _$NewPersonalRecordDto {
  const factory NewPersonalRecordDto({
    required String exerciseId,
    required String exerciseName,
    required String recordType,
    required double value,
    required String achievedAt,
  }) = _NewPersonalRecordDto;

  factory NewPersonalRecordDto.fromJson(Map<String, dynamic> json) =>
      _$NewPersonalRecordDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Complete session response
// ---------------------------------------------------------------------------

@freezed
abstract class CompleteSessionDataDto with _$CompleteSessionDataDto {
  const factory CompleteSessionDataDto({
    required SessionDetailDto session,
    @Default([]) List<NewPersonalRecordDto> newPersonalRecords,
  }) = _CompleteSessionDataDto;

  factory CompleteSessionDataDto.fromJson(Map<String, dynamic> json) =>
      _$CompleteSessionDataDtoFromJson(json);
}

@freezed
abstract class CompleteSessionEnvelopeDto with _$CompleteSessionEnvelopeDto {
  const factory CompleteSessionEnvelopeDto({
    required int status,
    required CompleteSessionDataDto data,
  }) = _CompleteSessionEnvelopeDto;

  factory CompleteSessionEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$CompleteSessionEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// RPE-to-weight suggestion response
// ---------------------------------------------------------------------------

@freezed
abstract class RpeSuggestionBasedOnDto with _$RpeSuggestionBasedOnDto {
  const factory RpeSuggestionBasedOnDto({
    required double weightKg,
    required double rpe,
    required String sessionDate,
  }) = _RpeSuggestionBasedOnDto;

  factory RpeSuggestionBasedOnDto.fromJson(Map<String, dynamic> json) =>
      _$RpeSuggestionBasedOnDtoFromJson(json);
}

@freezed
abstract class RpeSuggestionDataDto with _$RpeSuggestionDataDto {
  const factory RpeSuggestionDataDto({
    double? suggestedWeight,
    RpeSuggestionBasedOnDto? basedOn,
  }) = _RpeSuggestionDataDto;

  factory RpeSuggestionDataDto.fromJson(Map<String, dynamic> json) =>
      _$RpeSuggestionDataDtoFromJson(json);
}

@freezed
abstract class RpeSuggestionEnvelopeDto with _$RpeSuggestionEnvelopeDto {
  const factory RpeSuggestionEnvelopeDto({
    required int status,
    required RpeSuggestionDataDto data,
  }) = _RpeSuggestionEnvelopeDto;

  factory RpeSuggestionEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$RpeSuggestionEnvelopeDtoFromJson(json);
}
