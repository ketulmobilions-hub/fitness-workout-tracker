import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_preferences.freezed.dart';

@freezed
abstract class NotificationPreferences with _$NotificationPreferences {
  const factory NotificationPreferences({
    @Default(true) bool workoutReminders,
    @Default(true) bool streakAlerts,
    @Default(true) bool weeklyReport,
  }) = _NotificationPreferences;
}

enum UnitsPreference { metric, imperial }

enum ThemePreference { light, dark, system }

@freezed
abstract class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    @Default(UnitsPreference.metric) UnitsPreference units,
    @Default(ThemePreference.system) ThemePreference theme,
    @Default(NotificationPreferences()) NotificationPreferences notifications,
  }) = _UserPreferences;
}
