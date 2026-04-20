import 'package:freezed_annotation/freezed_annotation.dart';

part 'streak_dtos.freezed.dart';
part 'streak_dtos.g.dart';

// ---------------------------------------------------------------------------
// Current streak DTO
// ---------------------------------------------------------------------------

@freezed
abstract class StreakDto with _$StreakDto {
  const factory StreakDto({
    required int currentStreak,
    required int longestStreak,
    String? lastWorkoutDate,
  }) = _StreakDto;

  factory StreakDto.fromJson(Map<String, dynamic> json) =>
      _$StreakDtoFromJson(json);
}

@freezed
abstract class StreakEnvelopeDto with _$StreakEnvelopeDto {
  const factory StreakEnvelopeDto({
    required int status,
    required StreakDto data,
  }) = _StreakEnvelopeDto;

  factory StreakEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$StreakEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Streak history DTOs
// ---------------------------------------------------------------------------

@freezed
abstract class StreakHistoryEntryDto with _$StreakHistoryEntryDto {
  const factory StreakHistoryEntryDto({
    required String date,
    required String status,
  }) = _StreakHistoryEntryDto;

  factory StreakHistoryEntryDto.fromJson(Map<String, dynamic> json) =>
      _$StreakHistoryEntryDtoFromJson(json);
}

@freezed
abstract class StreakHistoryDataDto with _$StreakHistoryDataDto {
  const factory StreakHistoryDataDto({
    @Default([]) List<StreakHistoryEntryDto> history,
  }) = _StreakHistoryDataDto;

  factory StreakHistoryDataDto.fromJson(Map<String, dynamic> json) =>
      _$StreakHistoryDataDtoFromJson(json);
}

@freezed
abstract class StreakHistoryEnvelopeDto with _$StreakHistoryEnvelopeDto {
  const factory StreakHistoryEnvelopeDto({
    required int status,
    required StreakHistoryDataDto data,
  }) = _StreakHistoryEnvelopeDto;

  factory StreakHistoryEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$StreakHistoryEnvelopeDtoFromJson(json);
}
