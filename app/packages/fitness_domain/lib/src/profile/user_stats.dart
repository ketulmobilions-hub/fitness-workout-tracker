import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_stats.freezed.dart';

@freezed
abstract class UserStats with _$UserStats {
  const factory UserStats({
    required int totalWorkouts,
    required double totalVolumeKg,
    required int currentStreak,
    required int longestStreak,
    required DateTime memberSince,
    DateTime? lastWorkoutDate,
  }) = _UserStats;
}
