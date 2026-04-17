import 'package:freezed_annotation/freezed_annotation.dart';

part 'progress_overview.freezed.dart';

@freezed
abstract class ProgressOverview with _$ProgressOverview {
  const factory ProgressOverview({
    required int totalWorkouts,
    required double volumeThisWeek,
    required double volumeThisMonth,
    required int currentStreak,
    required int longestStreak,
    String? lastWorkoutDate,
  }) = _ProgressOverview;
}
