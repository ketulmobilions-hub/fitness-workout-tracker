import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_progress.freezed.dart';

@freezed
abstract class ExerciseHistoryPoint with _$ExerciseHistoryPoint {
  const factory ExerciseHistoryPoint({
    required String date,
    double? maxWeight,
    required double totalVolume,
    required int totalReps,
    required int setsCount,
  }) = _ExerciseHistoryPoint;
}

@freezed
abstract class ExercisePersonalRecords with _$ExercisePersonalRecords {
  const factory ExercisePersonalRecords({
    double? maxWeight,
    double? maxReps,
    double? maxVolume,
    double? bestPace,
  }) = _ExercisePersonalRecords;
}

@freezed
abstract class ExerciseProgressInfo with _$ExerciseProgressInfo {
  const factory ExerciseProgressInfo({
    required String id,
    required String name,
    required String type,
  }) = _ExerciseProgressInfo;
}

@freezed
abstract class ExerciseProgress with _$ExerciseProgress {
  const factory ExerciseProgress({
    required ExerciseProgressInfo exercise,
    required ExercisePersonalRecords personalRecords,
    double? estimatedOneRepMax,
    @Default([]) List<ExerciseHistoryPoint> history,
  }) = _ExerciseProgress;
}
