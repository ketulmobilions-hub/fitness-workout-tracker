import 'package:freezed_annotation/freezed_annotation.dart';

import 'exercise_dtos.dart';

part 'session_list_dto.freezed.dart';
part 'session_list_dto.g.dart';

// ---------------------------------------------------------------------------
// Session summary DTO (lightweight — used in list responses)
// ---------------------------------------------------------------------------

@freezed
abstract class SessionSummaryDto with _$SessionSummaryDto {
  const factory SessionSummaryDto({
    required String id,
    String? planId,
    String? planDayId,
    required String status,
    required String startedAt,
    String? completedAt,
    int? durationSec,
    String? notes,
    @Default(0) int exerciseCount,
    @Default(0) int totalSets,
    @Default(0.0) double totalVolumeKg,
    required String createdAt,
    required String updatedAt,
  }) = _SessionSummaryDto;

  factory SessionSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$SessionSummaryDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Session list data wrapper
// Reuses PaginationDto from exercise_dtos.dart — same structure.
// ---------------------------------------------------------------------------

@freezed
abstract class SessionListDataDto with _$SessionListDataDto {
  const factory SessionListDataDto({
    @Default([]) List<SessionSummaryDto> sessions,
    required PaginationDto pagination,
  }) = _SessionListDataDto;

  factory SessionListDataDto.fromJson(Map<String, dynamic> json) =>
      _$SessionListDataDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Session list envelope: { "status": 200, "data": { "sessions": [...] } }
// ---------------------------------------------------------------------------

@freezed
abstract class SessionListEnvelopeDto with _$SessionListEnvelopeDto {
  const factory SessionListEnvelopeDto({
    required int status,
    required SessionListDataDto data,
  }) = _SessionListEnvelopeDto;

  factory SessionListEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$SessionListEnvelopeDtoFromJson(json);
}
