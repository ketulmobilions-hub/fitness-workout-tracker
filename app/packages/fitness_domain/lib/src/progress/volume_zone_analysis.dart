import 'package:freezed_annotation/freezed_annotation.dart';

part 'volume_zone_analysis.freezed.dart';

/// One week's worth of training broken down by intensity zone.
/// Intensity = weight_kg / estimated_1rm at session time.
/// Zones: technique <60%, hypertrophy 60–75%, strength 75–90%, max effort ≥90%.
@freezed
abstract class VolumeZoneWeek with _$VolumeZoneWeek {
  const VolumeZoneWeek._();

  const factory VolumeZoneWeek({
    required DateTime weekStart,
    required bool isDeload,
    required int techniqueSets,
    required double techniqueTonnageKg,
    required int hypertrophySets,
    required double hypertrophyTonnageKg,
    required int strengthSets,
    required double strengthTonnageKg,
    required int maxEffortSets,
    required double maxEffortTonnageKg,
  }) = _VolumeZoneWeek;

  int get totalSets =>
      techniqueSets + hypertrophySets + strengthSets + maxEffortSets;

  double get totalTonnageKg =>
      techniqueTonnageKg +
      hypertrophyTonnageKg +
      strengthTonnageKg +
      maxEffortTonnageKg;
}

@freezed
abstract class VolumeZoneAnalysis with _$VolumeZoneAnalysis {
  const VolumeZoneAnalysis._();

  const factory VolumeZoneAnalysis({
    required int weeks,
    @Default([]) List<VolumeZoneWeek> data,
  }) = _VolumeZoneAnalysis;
}
