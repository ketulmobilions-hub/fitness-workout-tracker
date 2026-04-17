import 'package:dio/dio.dart';
import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl({required ProgressApiClient apiClient})
      : _apiClient = apiClient;

  final ProgressApiClient _apiClient;

  // Map Dio errors to typed messages at the repository boundary so providers
  // receive friendly strings instead of raw Dio internals. A 401 is surfaced
  // distinctly so the UI can prompt re-authentication.
  Never _mapDioError(DioException e) {
    if (e.response?.statusCode == 401) {
      throw Exception('Your session has expired. Please log in again.');
    }
    throw Exception('Network error: ${e.message ?? e.type.name}');
  }

  // Issue #1: catch all exceptions, not just DioException. Non-Dio errors
  // (e.g. TypeError from malformed JSON, FormatException from unexpected
  // server responses) would otherwise surface as raw Dart stack traces in the
  // UI instead of a friendly retry message.
  Never _mapError(Object e) {
    // `return` is required so that the compiler treats the DioException branch
    // as unconditionally terminating. Without it the code compiles (because
    // _mapDioError is typed Never), but if _mapDioError's return type were ever
    // changed to void the branch would silently fall through to the generic
    // message, swallowing the 401-aware re-auth hint (Issue #1).
    if (e is DioException) return _mapDioError(e);
    throw Exception('Unexpected error: $e');
  }

  @override
  Future<ProgressOverview> fetchOverview(int utcOffset) async {
    try {
      final envelope = await _apiClient.getOverview(utcOffset: utcOffset);
      final dto = envelope.data;
      return ProgressOverview(
        totalWorkouts: dto.totalWorkouts,
        volumeThisWeek: dto.volumeThisWeek,
        volumeThisMonth: dto.volumeThisMonth,
        currentStreak: dto.currentStreak,
        longestStreak: dto.longestStreak,
        lastWorkoutDate: dto.lastWorkoutDate,
      );
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<ExerciseProgress> fetchExerciseProgress(
    String exerciseId,
    String period,
  ) async {
    try {
      final envelope =
          await _apiClient.getExerciseProgress(exerciseId, period: period);
      final dto = envelope.data;
      return ExerciseProgress(
        exercise: ExerciseProgressInfo(
          id: dto.exercise.id,
          name: dto.exercise.name,
          type: dto.exercise.type,
        ),
        personalRecords: ExercisePersonalRecords(
          maxWeight: dto.personalRecords.maxWeight,
          maxReps: dto.personalRecords.maxReps,
          maxVolume: dto.personalRecords.maxVolume,
          bestPace: dto.personalRecords.bestPace,
        ),
        estimatedOneRepMax: dto.estimatedOneRepMax,
        history: dto.history
            .map(
              (h) => ExerciseHistoryPoint(
                date: h.date,
                maxWeight: h.maxWeight,
                totalVolume: h.totalVolume,
                totalReps: h.totalReps,
                setsCount: h.setsCount,
              ),
            )
            .toList(),
      );
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<List<ProgressPersonalRecord>> fetchPersonalRecords({
    String? exerciseId,
    String? recordType,
  }) async {
    try {
      final envelope = await _apiClient.getPersonalRecords(
        exerciseId: exerciseId,
        recordType: recordType,
      );
      return envelope.data.data
          .map(
            (dto) => ProgressPersonalRecord(
              id: dto.id,
              exerciseId: dto.exercise.id,
              exerciseName: dto.exercise.name,
              recordType: dto.recordType,
              value: dto.value,
              achievedAt: dto.achievedAt,
              sessionId: dto.sessionId,
            ),
          )
          .toList();
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<VolumeData> fetchVolume(String period, {String? granularity}) async {
    try {
      final envelope = await _apiClient.getVolume(
        period: period,
        granularity: granularity,
      );
      final dto = envelope.data;
      return VolumeData(
        granularity: dto.granularity,
        buckets: dto.data
            .map(
              (b) => VolumeBucket(
                date: b.date,
                volume: b.volume,
                sessions: b.sessions,
              ),
            )
            .toList(),
      );
    } catch (e) {
      _mapError(e);
    }
  }
}
