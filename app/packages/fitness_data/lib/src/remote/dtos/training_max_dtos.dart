import 'package:freezed_annotation/freezed_annotation.dart';

part 'training_max_dtos.freezed.dart';
part 'training_max_dtos.g.dart';

@freezed
abstract class TrainingMaxDto with _$TrainingMaxDto {
  const factory TrainingMaxDto({
    required String id,
    required String exerciseId,
    required String exerciseName,
    required String exerciseType,
    required double trainingMaxKg,
    required double percentageOf1rm,
    double? latestPrKg,
    String? latestPrDate,
    required String updatedAt,
  }) = _TrainingMaxDto;

  factory TrainingMaxDto.fromJson(Map<String, dynamic> json) =>
      _$TrainingMaxDtoFromJson(json);
}

@freezed
abstract class TrainingMaxListEnvelopeDto with _$TrainingMaxListEnvelopeDto {
  const factory TrainingMaxListEnvelopeDto({
    required int status,
    @Default([]) List<TrainingMaxDto> data,
  }) = _TrainingMaxListEnvelopeDto;

  factory TrainingMaxListEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$TrainingMaxListEnvelopeDtoFromJson(json);
}

@freezed
abstract class TrainingMaxEnvelopeDto with _$TrainingMaxEnvelopeDto {
  const factory TrainingMaxEnvelopeDto({
    required int status,
    required TrainingMaxDto data,
  }) = _TrainingMaxEnvelopeDto;

  factory TrainingMaxEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$TrainingMaxEnvelopeDtoFromJson(json);
}
