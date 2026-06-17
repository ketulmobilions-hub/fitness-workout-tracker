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
    // Strength scores — null when bodyweight/gender not set or no SBD PRs.
    double? wilks,
    double? dots,
    double? ipfGl,
  }) = _ProgressOverview;
}
