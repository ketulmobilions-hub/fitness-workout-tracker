import 'package:freezed_annotation/freezed_annotation.dart';

part 'competition_dtos.freezed.dart';
part 'competition_dtos.g.dart';

@freezed
abstract class CompetitionAttemptDto with _$CompetitionAttemptDto {
  const factory CompetitionAttemptDto({
    required String id,
    required String liftType,
    required int attemptNumber,
    required double weightKg,
    required String result,
  }) = _CompetitionAttemptDto;

  factory CompetitionAttemptDto.fromJson(Map<String, dynamic> json) =>
      _$CompetitionAttemptDtoFromJson(json);
}

@freezed
abstract class CompetitionDto with _$CompetitionDto {
  const factory CompetitionDto({
    required String id,
    required String name,
    String? federation,
    required String date,
    String? location,
    double? weightClassKg,
    double? bodyweightKg,
    String? division,
    required String status,
    @Default([]) List<CompetitionAttemptDto> attempts,
    double? squat,
    double? bench,
    double? deadlift,
    double? total,
    double? wilks,
    double? dots,
    double? ipfGl,
    required String createdAt,
    required String updatedAt,
  }) = _CompetitionDto;

  factory CompetitionDto.fromJson(Map<String, dynamic> json) =>
      _$CompetitionDtoFromJson(json);
}

@freezed
abstract class CompetitionEnvelopeDto with _$CompetitionEnvelopeDto {
  const factory CompetitionEnvelopeDto({
    required int status,
    required CompetitionDto data,
  }) = _CompetitionEnvelopeDto;

  factory CompetitionEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$CompetitionEnvelopeDtoFromJson(json);
}

@freezed
abstract class CompetitionListEnvelopeDto with _$CompetitionListEnvelopeDto {
  const factory CompetitionListEnvelopeDto({
    required int status,
    @Default([]) List<CompetitionDto> data,
  }) = _CompetitionListEnvelopeDto;

  factory CompetitionListEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$CompetitionListEnvelopeDtoFromJson(json);
}

@freezed
abstract class CompetitionAttemptEnvelopeDto
    with _$CompetitionAttemptEnvelopeDto {
  const factory CompetitionAttemptEnvelopeDto({
    required int status,
    required CompetitionAttemptDto data,
  }) = _CompetitionAttemptEnvelopeDto;

  factory CompetitionAttemptEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$CompetitionAttemptEnvelopeDtoFromJson(json);
}

// DTO for updating competition metadata (status only — creation uses separate model)
@freezed
abstract class CompetitionUpdateDto with _$CompetitionUpdateDto {
  const factory CompetitionUpdateDto({
    required String id,
    required String name,
    String? federation,
    required String date,
    String? location,
    double? weightClassKg,
    double? bodyweightKg,
    String? division,
    required String status,
    required String updatedAt,
  }) = _CompetitionUpdateDto;

  factory CompetitionUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$CompetitionUpdateDtoFromJson(json);
}

@freezed
abstract class CompetitionUpdateEnvelopeDto
    with _$CompetitionUpdateEnvelopeDto {
  const factory CompetitionUpdateEnvelopeDto({
    required int status,
    required CompetitionUpdateDto data,
  }) = _CompetitionUpdateEnvelopeDto;

  factory CompetitionUpdateEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$CompetitionUpdateEnvelopeDtoFromJson(json);
}
