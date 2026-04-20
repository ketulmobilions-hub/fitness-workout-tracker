import 'package:freezed_annotation/freezed_annotation.dart';

import 'streak_day_status.dart';

part 'streak_day.freezed.dart';

@freezed
abstract class StreakDay with _$StreakDay {
  const factory StreakDay({
    required String date,
    required StreakDayStatus status,
  }) = _StreakDay;
}
