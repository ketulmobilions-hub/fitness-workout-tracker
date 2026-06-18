import 'package:freezed_annotation/freezed_annotation.dart';

part 'sbd_total.freezed.dart';

/// One monthly data point in the SBD training total trend.
/// Only months where all three lifts (S/B/D) have a cumulative best PR are
/// included. `total` is intentionally omitted — it is always `squat + bench +
/// deadlift` and computing it here would allow the model to hold inconsistent
/// state due to floating-point rounding differences vs the server's value.
/// Compute at display time: `squat + bench + deadlift`.
@freezed
abstract class SbdMonthPoint with _$SbdMonthPoint {
  const factory SbdMonthPoint({
    required String month, // 'YYYY-MM'
    required double squat,
    required double bench,
    required double deadlift,
  }) = _SbdMonthPoint;
}

/// The user's all-time best SBD training total plus a 12-month trend.
@freezed
abstract class SbdTotal with _$SbdTotal {
  const factory SbdTotal({
    double? squat,
    double? bench,
    double? deadlift,
    double? total,
    @Default(0) int liftCount,
    @Default([]) List<SbdMonthPoint> monthly,
    double? monthOverMonthDelta,
    String? deltaVsMonth,
  }) = _SbdTotal;
}
