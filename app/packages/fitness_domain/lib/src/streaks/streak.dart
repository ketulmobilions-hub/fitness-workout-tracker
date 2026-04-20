import 'package:freezed_annotation/freezed_annotation.dart';

part 'streak.freezed.dart';

@freezed
abstract class Streak with _$Streak {
  const factory Streak({
    required int currentStreak,
    required int longestStreak,
    String? lastWorkoutDate,
  }) = _Streak;
}
