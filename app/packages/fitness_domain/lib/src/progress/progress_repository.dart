import 'exercise_progress.dart';
import 'progress_overview.dart';
import 'progress_personal_record.dart';
import 'sbd_total.dart';
import 'score_history.dart';
import 'volume_data.dart';
import 'volume_zone_analysis.dart';

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

  /// Fetches the last 24 months of Wilks/Dots/IPF GL score history.
  /// Only months where all three SBD PRs exist are included.
  Future<ScoreHistory> fetchScoreHistory();

  /// Fetches the user's all-time best SBD training total (squat + bench +
  /// deadlift) plus a 12-month monthly trend.
  Future<SbdTotal> fetchSbdTotal();

  /// Fetches per-week volume breakdown by intensity zone for competition lifts.
  /// [weeks] — how many weeks back to look (default 12, max 52).
  /// [utcOffset] — device UTC offset in minutes; aligns week boundaries to
  /// the user's local calendar (same convention as fetchOverview).
  Future<VolumeZoneAnalysis> fetchVolumeZones({int weeks = 12, int utcOffset = 0});
}
