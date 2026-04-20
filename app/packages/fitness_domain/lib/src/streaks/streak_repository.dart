import 'streak.dart';
import 'streak_day.dart';

export 'streak.dart';
export 'streak_day.dart';
export 'streak_day_status.dart';

abstract class StreakRepository {
  Stream<Streak?> watchStreak(String userId);
  Stream<List<StreakDay>> watchStreakHistory(String userId, {DateTime? since});
  Future<void> refreshStreak(String userId);
  Future<void> refreshStreakHistory(String userId, int year, int month);
}
