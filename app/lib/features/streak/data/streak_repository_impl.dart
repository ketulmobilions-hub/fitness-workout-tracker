import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fitness_data/fitness_data.dart' as data;
import 'package:fitness_domain/fitness_domain.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class StreakRepositoryImpl implements StreakRepository {
  StreakRepositoryImpl({
    required data.StreakApiClient apiClient,
    required data.ProgressDao progressDao,
  })  : _apiClient = apiClient,
        _dao = progressDao;

  final data.StreakApiClient _apiClient;
  final data.ProgressDao _dao;

  Never _mapDioError(DioException e) {
    if (e.response?.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }
    throw Exception('Network error: ${e.message ?? e.type.name}');
  }

  Never _mapError(Object e) {
    if (e is DioException) return _mapDioError(e);
    throw Exception('Unexpected error: $e');
  }

  @override
  Stream<Streak?> watchStreak(String userId) {
    return _dao.watchStreak(userId).map((row) {
      if (row == null) return null;
      return Streak(
        currentStreak: row.currentStreak,
        longestStreak: row.longestStreak,
        lastWorkoutDate: row.lastWorkoutDate != null
            ? _formatDate(row.lastWorkoutDate!)
            : null,
      );
    });
  }

  @override
  Stream<List<StreakDay>> watchStreakHistory(
    String userId, {
    DateTime? since,
  }) {
    return _dao.watchStreakHistory(userId, since: since).map(
          (rows) => rows.map(_rowToStreakDay).toList(),
        );
  }

  @override
  Future<void> refreshStreak(String userId) async {
    try {
      final envelope = await _apiClient.getStreak();
      final dto = envelope.data;
      await _dao.upsertStreak(
        data.StreaksCompanion(
          id: Value(_uuid.v4()),
          userId: Value(userId),
          currentStreak: Value(dto.currentStreak),
          longestStreak: Value(dto.longestStreak),
          lastWorkoutDate: Value(
            dto.lastWorkoutDate != null
                ? _parseDate(dto.lastWorkoutDate!)
                : null,
          ),
        ),
      );
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<void> refreshStreakHistory(
    String userId,
    int year,
    int month,
  ) async {
    try {
      final envelope =
          await _apiClient.getStreakHistory(year: year, month: month);
      await Future.wait(
        envelope.data.history.map((entry) {
          final date = _parseDate(entry.date);
          final status = _parseDataStatus(entry.status);
          return _dao.upsertStreakHistoryEntry(
            data.StreakHistoryCompanion(
              id: Value(_uuid.v4()),
              userId: Value(userId),
              date: Value(date),
              status: Value(status),
            ),
          );
        }),
      );
    } catch (e) {
      _mapError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  StreakDay _rowToStreakDay(data.StreakHistoryRow row) {
    return StreakDay(
      date: _formatDate(row.date),
      status: row.status,
    );
  }

  data.StreakDayStatus _parseDataStatus(String raw) {
    return switch (raw) {
      'completed' => data.StreakDayStatus.completed,
      'rest_day' => data.StreakDayStatus.restDay,
      'missed' => data.StreakDayStatus.missed,
      _ => data.StreakDayStatus.missed,
    };
  }

  DateTime _parseDate(String yyyyMmDd) {
    final parts = yyyyMmDd.split('-');
    if (parts.length < 3) {
      throw FormatException('Invalid date format: $yyyyMmDd');
    }
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
