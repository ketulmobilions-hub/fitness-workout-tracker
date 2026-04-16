import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_request_dtos.freezed.dart';
part 'session_request_dtos.g.dart';

@freezed
abstract class StartSessionRequestDto with _$StartSessionRequestDto {
  const factory StartSessionRequestDto({
    String? planId,
    String? planDayId,
    String? startedAt,
  }) = _StartSessionRequestDto;

  factory StartSessionRequestDto.fromJson(Map<String, dynamic> json) =>
      _$StartSessionRequestDtoFromJson(json);
}

@freezed
abstract class LogSetRequestDto with _$LogSetRequestDto {
  const factory LogSetRequestDto({
    required String exerciseId,
    required int setNumber,
    int? reps,
    double? weightKg,
    int? durationSec,
    double? distanceM,
    double? paceSecPerKm,
    int? heartRate,
    int? rpe,
    String? tempo,
    bool? isWarmup,
    String? completedAt,
  }) = _LogSetRequestDto;

  factory LogSetRequestDto.fromJson(Map<String, dynamic> json) =>
      _$LogSetRequestDtoFromJson(json);
}

@freezed
abstract class UpdateSessionRequestDto with _$UpdateSessionRequestDto {
  const factory UpdateSessionRequestDto({
    String? notes,
    String? status,
  }) = _UpdateSessionRequestDto;

  factory UpdateSessionRequestDto.fromJson(Map<String, dynamic> json) =>
      _$UpdateSessionRequestDtoFromJson(json);
}

@freezed
abstract class CompleteSessionRequestDto with _$CompleteSessionRequestDto {
  const factory CompleteSessionRequestDto({
    String? completedAt,
    int? durationSec,
    String? notes,
  }) = _CompleteSessionRequestDto;

  factory CompleteSessionRequestDto.fromJson(Map<String, dynamic> json) =>
      _$CompleteSessionRequestDtoFromJson(json);
}
