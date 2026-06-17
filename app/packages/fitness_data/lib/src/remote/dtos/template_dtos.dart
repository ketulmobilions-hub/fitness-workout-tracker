import 'package:freezed_annotation/freezed_annotation.dart';

part 'template_dtos.freezed.dart';
part 'template_dtos.g.dart';

// Template exercise (inside a week/day)
@freezed
abstract class TemplateExerciseDto with _$TemplateExerciseDto {
  const factory TemplateExerciseDto({
    required String exerciseName,
    required int sortOrder,
    required int targetSets,
    String? targetReps,
    double? targetWeightPct1rm,
    double? targetRpe,
    String? notes,
  }) = _TemplateExerciseDto;

  factory TemplateExerciseDto.fromJson(Map<String, dynamic> json) =>
      _$TemplateExerciseDtoFromJson(json);
}

// Template day (inside a week)
@freezed
abstract class TemplateDayDto with _$TemplateDayDto {
  const factory TemplateDayDto({
    required int dayOfWeek,
    required String name,
    required int sortOrder,
    @Default([]) List<TemplateExerciseDto> exercises,
  }) = _TemplateDayDto;

  factory TemplateDayDto.fromJson(Map<String, dynamic> json) =>
      _$TemplateDayDtoFromJson(json);
}

// Template week
@freezed
abstract class TemplateWeekDto with _$TemplateWeekDto {
  const factory TemplateWeekDto({
    required int weekNumber,
    @Default([]) List<TemplateDayDto> days,
  }) = _TemplateWeekDto;

  factory TemplateWeekDto.fromJson(Map<String, dynamic> json) =>
      _$TemplateWeekDtoFromJson(json);
}

// Template summary (returned by list endpoint — no weeks)
@freezed
abstract class TemplateSummaryDto with _$TemplateSummaryDto {
  const factory TemplateSummaryDto({
    required String id,
    required String name,
    required String description,
    required int weeksCount,
    required int daysPerWeek,
    required String difficulty,
    required String category,
    @Default([]) List<String> tags,
  }) = _TemplateSummaryDto;

  factory TemplateSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$TemplateSummaryDtoFromJson(json);
}

// Template detail (returned by get-by-id — includes weeks)
@freezed
abstract class TemplateDetailDto with _$TemplateDetailDto {
  const factory TemplateDetailDto({
    required String id,
    required String name,
    required String description,
    required int weeksCount,
    required int daysPerWeek,
    required String difficulty,
    required String category,
    @Default([]) List<String> tags,
    @Default([]) List<TemplateWeekDto> weeks,
  }) = _TemplateDetailDto;

  factory TemplateDetailDto.fromJson(Map<String, dynamic> json) =>
      _$TemplateDetailDtoFromJson(json);
}

// List response envelope
@freezed
abstract class TemplateListDataDto with _$TemplateListDataDto {
  const factory TemplateListDataDto({
    @Default([]) List<TemplateSummaryDto> templates,
  }) = _TemplateListDataDto;

  factory TemplateListDataDto.fromJson(Map<String, dynamic> json) =>
      _$TemplateListDataDtoFromJson(json);
}

@freezed
abstract class TemplateListEnvelopeDto with _$TemplateListEnvelopeDto {
  const factory TemplateListEnvelopeDto({
    required int status,
    required TemplateListDataDto data,
  }) = _TemplateListEnvelopeDto;

  factory TemplateListEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$TemplateListEnvelopeDtoFromJson(json);
}

// Detail response envelope
@freezed
abstract class TemplateDetailDataDto with _$TemplateDetailDataDto {
  const factory TemplateDetailDataDto({
    required TemplateDetailDto template,
  }) = _TemplateDetailDataDto;

  factory TemplateDetailDataDto.fromJson(Map<String, dynamic> json) =>
      _$TemplateDetailDataDtoFromJson(json);
}

@freezed
abstract class TemplateDetailEnvelopeDto with _$TemplateDetailEnvelopeDto {
  const factory TemplateDetailEnvelopeDto({
    required int status,
    required TemplateDetailDataDto data,
  }) = _TemplateDetailEnvelopeDto;

  factory TemplateDetailEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$TemplateDetailEnvelopeDtoFromJson(json);
}
