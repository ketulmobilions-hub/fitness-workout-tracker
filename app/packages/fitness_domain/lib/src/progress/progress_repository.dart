import 'exercise_progress.dart';
import 'progress_overview.dart';
import 'progress_personal_record.dart';
import 'volume_data.dart';

abstract class ProgressRepository {
  /// Fetches summary stats for the current user.
  ///
  /// [utcOffset] is the device's UTC offset in minutes (e.g., 330 for IST,
  /// -300 for EST). Used by the server to align week/month boundaries to the
  /// user's local calendar.
  Future<ProgressOverview> fetchOverview(int utcOffset);

  /// Fetches exercise-specific progression data.
  ///
  /// [period] must be one of: '1m', '3m', '6m', '1y', 'all'.
  Future<ExerciseProgress> fetchExerciseProgress(
    String exerciseId,
    String period,
  );

  /// Fetches the user's personal records, optionally filtered by exercise or
  /// record type.
  ///
  /// [recordType] must be one of: 'max_weight', 'max_reps', 'max_volume',
  /// 'best_pace'.
  Future<List<ProgressPersonalRecord>> fetchPersonalRecords({
    String? exerciseId,
    String? recordType,
  });

  /// Fetches volume trend data for the given period.
  ///
  /// [period] must be one of: '1w', '1m', '3m', '6m', '1y'.
  /// [granularity] is auto-inferred by the server when omitted.
  Future<VolumeData> fetchVolume(String period, {String? granularity});
}
