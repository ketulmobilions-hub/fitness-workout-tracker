import 'package:freezed_annotation/freezed_annotation.dart';

part 'score_history.freezed.dart';

/// One monthly data point in a strength score trend.
/// Months without all-three SBD PRs are omitted (null month → no point).
@freezed
abstract class ScoreHistoryPoint with _$ScoreHistoryPoint {
  const factory ScoreHistoryPoint({
    required String month, // 'YYYY-MM'
    double? wilks,
    double? dots,
    double? ipfGl,
  }) = _ScoreHistoryPoint;
}

/// The full 24-month strength score trend for a user.
@freezed
abstract class ScoreHistory with _$ScoreHistory {
  const factory ScoreHistory({
    @Default([]) List<ScoreHistoryPoint> points,
  }) = _ScoreHistory;
}
