import 'package:freezed_annotation/freezed_annotation.dart';

import 'session_status.dart';

part 'workout_session.freezed.dart';

@freezed
abstract class WorkoutSession with _$WorkoutSession {
  const factory WorkoutSession({
    required String id,
    required String userId,
    String? planId,
    String? planDayId,
    required DateTime startedAt,
    DateTime? completedAt,
    int? durationSec,
    String? notes,
    required SessionStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _WorkoutSession;
}

@freezed
abstract class ExerciseLog with _$ExerciseLog {
  const factory ExerciseLog({
    required String id,
    required String sessionId,
    required String exerciseId,
    required String exerciseName,
    required int sortOrder,
    String? notes,
    @Default([]) List<SetLog> sets,
  }) = _ExerciseLog;
}

@freezed
abstract class SetLog with _$SetLog {
  const factory SetLog({
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
    DateTime? completedAt,
  }) = _SetLog;
}

@freezed
abstract class NewPersonalRecord with _$NewPersonalRecord {
  const factory NewPersonalRecord({
    required String exerciseId,
    required String exerciseName,
    required String recordType,
    required double value,
    required DateTime achievedAt,
  }) = _NewPersonalRecord;
}
