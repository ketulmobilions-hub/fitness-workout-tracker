import 'package:freezed_annotation/freezed_annotation.dart';

part 'progress_personal_record.freezed.dart';

@freezed
abstract class ProgressPersonalRecord with _$ProgressPersonalRecord {
  const factory ProgressPersonalRecord({
    required String id,
    required String exerciseId,
    required String exerciseName,
    required String recordType,
    required double value,
    required String achievedAt,
    String? sessionId,
  }) = _ProgressPersonalRecord;
}
