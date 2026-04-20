import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fitness_data/fitness_data.dart' as data;
import 'package:fitness_domain/fitness_domain.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required data.UserApiClient apiClient,
    required data.UserDao userDao,
    required Future<void> Function() clearTokens,
  })  : _apiClient = apiClient,
        _userDao = userDao,
        _clearTokens = clearTokens;

  final data.UserApiClient _apiClient;
  final data.UserDao _userDao;
  final Future<void> Function() _clearTokens;

  @override
  Stream<UserProfile?> watchProfile(String userId) {
    return _userDao.watchUser(userId).map((row) {
      if (row == null) return null;
      return _rowToProfile(row);
    });
  }

  @override
  Future<UserProfile> refreshProfile(String userId) async {
    try {
      final envelope = await _apiClient.getProfile();
      final dto = envelope.data;
      await _userDao.upsertUser(_dtoToCompanion(dto));
      // Issue #1: graceful null check — avoids opaque null-check crash if
      // Drift unexpectedly returns null immediately after an upsert.
      final row = await _userDao.getUser(dto.id);
      if (row == null) throw Exception('Profile not found after save');
      return _rowToProfile(row);
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<UserProfile> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async {
    try {
      final envelope = await _apiClient.updateProfile(
        data.UpdateProfileRequestDto(
          displayName: displayName,
          avatarUrl: avatarUrl,
          bio: bio,
        ),
      );
      final dto = envelope.data;
      await _userDao.upsertUser(_dtoToCompanion(dto));
      // Issue #1: graceful null check after upsert.
      final row = await _userDao.getUser(dto.id);
      if (row == null) throw Exception('Profile not found after save');
      return _rowToProfile(row);
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<UserPreferences> updatePreferences(
    String userId,
    UserPreferences prefs,
  ) async {
    try {
      final envelope = await _apiClient.updatePreferences(
        data.UpdatePreferencesRequestDto(
          units: prefs.units == UnitsPreference.metric ? 'metric' : 'imperial',
          theme: switch (prefs.theme) {
            ThemePreference.light => 'light',
            ThemePreference.dark => 'dark',
            ThemePreference.system => 'system',
          },
          notifications: data.UpdateNotificationPreferencesDto(
            workoutReminders: prefs.notifications.workoutReminders,
            streakAlerts: prefs.notifications.streakAlerts,
            weeklyReport: prefs.notifications.weeklyReport,
          ),
        ),
      );
      final updated = _dtoToPreferences(envelope.data);

      // Issue #2: persist server-confirmed preferences back to Drift so the
      // watchProfile stream reflects the new values immediately without
      // waiting for a full refreshProfile call.
      final currentRow = await _userDao.getUser(userId);
      if (currentRow != null) {
        await _userDao.upsertUser(
          data.UsersCompanion(
            id: Value(currentRow.id),
            email: Value(currentRow.email),
            displayName: Value(currentRow.displayName),
            avatarUrl: Value(currentRow.avatarUrl),
            bio: Value(currentRow.bio),
            authProvider: Value(currentRow.authProvider),
            isGuest: Value(currentRow.isGuest),
            preferences: Value(_preferencesMapFromDomain(updated)),
          ),
        );
      }

      return updated;
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<UserStats> getStats() async {
    try {
      final envelope = await _apiClient.getStats();
      final dto = envelope.data;
      return UserStats(
        totalWorkouts: dto.totalWorkouts,
        totalVolumeKg: dto.totalVolumeKg,
        currentStreak: dto.currentStreak,
        longestStreak: dto.longestStreak,
        memberSince: DateTime.parse(dto.memberSince),
        lastWorkoutDate: dto.lastWorkoutDate != null
            ? DateTime.parse(dto.lastWorkoutDate!)
            : null,
      );
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    try {
      await _apiClient.deleteAccount();
      // Issue #3: remove the local Drift row so no ghost data lingers on device.
      await _userDao.deleteUser(userId);
      await _clearTokens();
    } catch (e) {
      _mapError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  UserProfile _rowToProfile(data.UserRow row) {
    // Issue #5: JsonStringConverter always returns Map<String, dynamic>, never
    // null. No unsafe cast or dead-code fallback needed.
    final prefsMap = row.preferences;
    return UserProfile(
      id: row.id,
      email: row.email.startsWith('guest:') ? null : row.email,
      // Issue #20: The Drift column is non-nullable so we store '' when the
      // server sends null. Convert '' back to null here so callers see a
      // proper absent value and fallback labels work correctly.
      displayName: row.displayName.isEmpty ? null : row.displayName,
      avatarUrl: row.avatarUrl,
      bio: row.bio,
      authProvider: _convertAuthProvider(row.authProvider),
      isGuest: row.isGuest,
      preferences: _mapToPreferences(prefsMap),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  data.UsersCompanion _dtoToCompanion(data.ProfileResponseDto dto) {
    return data.UsersCompanion(
      id: Value(dto.id),
      email: Value(dto.email ?? 'guest:${dto.id}'),
      // Store '' when null because Drift column is non-nullable.
      // _rowToProfile converts '' back to null on read.
      displayName: Value(dto.displayName ?? ''),
      avatarUrl: Value(dto.avatarUrl),
      bio: Value(dto.bio),
      authProvider: Value(_convertDtoAuthProvider(dto.authProvider)),
      isGuest: Value(dto.isGuest),
      preferences: Value(_preferencesFromDto(dto.preferences)),
      updatedAt: Value(DateTime.parse(dto.updatedAt)),
    );
  }

  UserPreferences _dtoToPreferences(data.UserPreferencesDto dto) {
    return UserPreferences(
      units: dto.units == 'imperial'
          ? UnitsPreference.imperial
          : UnitsPreference.metric,
      theme: switch (dto.theme) {
        'light' => ThemePreference.light,
        'dark' => ThemePreference.dark,
        _ => ThemePreference.system,
      },
      notifications: NotificationPreferences(
        workoutReminders: dto.notifications.workoutReminders,
        streakAlerts: dto.notifications.streakAlerts,
        weeklyReport: dto.notifications.weeklyReport,
      ),
    );
  }

  UserPreferences _mapToPreferences(Map<String, dynamic> map) {
    NotificationPreferences notifications = const NotificationPreferences();
    if (map['notifications'] is Map<String, dynamic>) {
      final n = map['notifications'] as Map<String, dynamic>;
      notifications = NotificationPreferences(
        workoutReminders: (n['workoutReminders'] as bool?) ?? true,
        streakAlerts: (n['streakAlerts'] as bool?) ?? true,
        weeklyReport: (n['weeklyReport'] as bool?) ?? true,
      );
    }
    return UserPreferences(
      units: map['units'] == 'imperial'
          ? UnitsPreference.imperial
          : UnitsPreference.metric,
      theme: switch (map['theme'] as String?) {
        'light' => ThemePreference.light,
        'dark' => ThemePreference.dark,
        _ => ThemePreference.system,
      },
      notifications: notifications,
    );
  }

  Map<String, dynamic> _preferencesFromDto(data.UserPreferencesDto dto) {
    return {
      'units': dto.units,
      'theme': dto.theme,
      'notifications': {
        'workoutReminders': dto.notifications.workoutReminders,
        'streakAlerts': dto.notifications.streakAlerts,
        'weeklyReport': dto.notifications.weeklyReport,
      },
    };
  }

  Map<String, dynamic> _preferencesMapFromDomain(UserPreferences prefs) {
    return {
      'units': prefs.units == UnitsPreference.metric ? 'metric' : 'imperial',
      'theme': switch (prefs.theme) {
        ThemePreference.light => 'light',
        ThemePreference.dark => 'dark',
        ThemePreference.system => 'system',
      },
      'notifications': {
        'workoutReminders': prefs.notifications.workoutReminders,
        'streakAlerts': prefs.notifications.streakAlerts,
        'weeklyReport': prefs.notifications.weeklyReport,
      },
    };
  }

  UserAuthProvider _convertAuthProvider(data.AuthProvider provider) {
    return switch (provider) {
      data.AuthProvider.emailPassword => UserAuthProvider.emailPassword,
      data.AuthProvider.google => UserAuthProvider.google,
      data.AuthProvider.apple => UserAuthProvider.apple,
      data.AuthProvider.guest => UserAuthProvider.guest,
    };
  }

  data.AuthProvider _convertDtoAuthProvider(String raw) {
    return switch (raw) {
      'google' => data.AuthProvider.google,
      'apple' => data.AuthProvider.apple,
      'guest' => data.AuthProvider.guest,
      _ => data.AuthProvider.emailPassword,
    };
  }

  Never _mapError(Object e) {
    if (e is DioException) {
      // Issue #4: 403 = requireFullAccount middleware blocked the request.
      // Surface a clear human-readable message instead of the raw HTTP error.
      if (e.response?.statusCode == 403) {
        throw Exception(
            'This action requires a full account. Please sign up to continue.');
      }
      if (e.response?.statusCode == 401) {
        throw Exception('Your session has expired. Please log in again.');
      }
      throw Exception('Network error: ${e.message ?? e.type.name}');
    }
    throw Exception('Unexpected error: $e');
  }
}
