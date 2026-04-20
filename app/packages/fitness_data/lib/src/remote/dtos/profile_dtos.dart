import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_dtos.freezed.dart';
part 'profile_dtos.g.dart';

// ---------------------------------------------------------------------------
// Response DTOs
// ---------------------------------------------------------------------------

@freezed
abstract class NotificationPreferencesDto with _$NotificationPreferencesDto {
  const factory NotificationPreferencesDto({
    @Default(true) bool workoutReminders,
    @Default(true) bool streakAlerts,
    @Default(true) bool weeklyReport,
  }) = _NotificationPreferencesDto;

  factory NotificationPreferencesDto.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesDtoFromJson(json);
}

@freezed
abstract class UserPreferencesDto with _$UserPreferencesDto {
  const factory UserPreferencesDto({
    @Default('metric') String units,
    @Default('system') String theme,
    @Default(NotificationPreferencesDto()) NotificationPreferencesDto notifications,
  }) = _UserPreferencesDto;

  factory UserPreferencesDto.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesDtoFromJson(json);
}

@freezed
abstract class ProfileResponseDto with _$ProfileResponseDto {
  const factory ProfileResponseDto({
    required String id,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? bio,
    required String authProvider,
    required bool isGuest,
    required UserPreferencesDto preferences,
    required String createdAt,
    required String updatedAt,
  }) = _ProfileResponseDto;

  factory ProfileResponseDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileResponseDtoFromJson(json);
}

@freezed
abstract class ProfileEnvelopeDto with _$ProfileEnvelopeDto {
  const factory ProfileEnvelopeDto({
    required ProfileResponseDto data,
  }) = _ProfileEnvelopeDto;

  factory ProfileEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileEnvelopeDtoFromJson(json);
}

@freezed
abstract class UserStatsDto with _$UserStatsDto {
  const factory UserStatsDto({
    required int totalWorkouts,
    required double totalVolumeKg,
    required int currentStreak,
    required int longestStreak,
    required String memberSince,
    String? lastWorkoutDate,
  }) = _UserStatsDto;

  factory UserStatsDto.fromJson(Map<String, dynamic> json) =>
      _$UserStatsDtoFromJson(json);
}

@freezed
abstract class StatsEnvelopeDto with _$StatsEnvelopeDto {
  const factory StatsEnvelopeDto({
    required UserStatsDto data,
  }) = _StatsEnvelopeDto;

  factory StatsEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$StatsEnvelopeDtoFromJson(json);
}

@freezed
abstract class PreferencesEnvelopeDto with _$PreferencesEnvelopeDto {
  const factory PreferencesEnvelopeDto({
    required UserPreferencesDto data,
  }) = _PreferencesEnvelopeDto;

  factory PreferencesEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$PreferencesEnvelopeDtoFromJson(json);
}

// ---------------------------------------------------------------------------
// Request DTOs
// ---------------------------------------------------------------------------

@freezed
abstract class UpdateProfileRequestDto with _$UpdateProfileRequestDto {
  const factory UpdateProfileRequestDto({
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) = _UpdateProfileRequestDto;

  factory UpdateProfileRequestDto.fromJson(Map<String, dynamic> json) =>
      _$UpdateProfileRequestDtoFromJson(json);
}

@freezed
abstract class UpdateNotificationPreferencesDto
    with _$UpdateNotificationPreferencesDto {
  const factory UpdateNotificationPreferencesDto({
    bool? workoutReminders,
    bool? streakAlerts,
    bool? weeklyReport,
  }) = _UpdateNotificationPreferencesDto;

  factory UpdateNotificationPreferencesDto.fromJson(
          Map<String, dynamic> json) =>
      _$UpdateNotificationPreferencesDtoFromJson(json);
}

@freezed
abstract class UpdatePreferencesRequestDto with _$UpdatePreferencesRequestDto {
  const factory UpdatePreferencesRequestDto({
    String? units,
    String? theme,
    UpdateNotificationPreferencesDto? notifications,
  }) = _UpdatePreferencesRequestDto;

  factory UpdatePreferencesRequestDto.fromJson(Map<String, dynamic> json) =>
      _$UpdatePreferencesRequestDtoFromJson(json);
}
