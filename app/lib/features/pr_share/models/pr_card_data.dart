import 'package:fitness_domain/fitness_domain.dart';

/// Flat data model for a PR share card. Constructed from either a session
/// [NewPersonalRecord] (with optional 1RM/RPE enrichment) or a history
/// [ProgressPersonalRecord].
class PrCardData {
  const PrCardData({
    required this.exerciseName,
    required this.recordType,
    required this.value,
    required this.achievedAt,
    this.estimatedOneRm,
    this.rpe,
    this.athleteName,
  });

  final String exerciseName;
  final String recordType;
  final double value;
  final DateTime achievedAt;
  final double? estimatedOneRm;
  final double? rpe;
  final String? athleteName;

  factory PrCardData.fromNewPr(
    NewPersonalRecord pr, {
    double? estimatedOneRm,
    double? rpe,
    String? athleteName,
  }) =>
      PrCardData(
        exerciseName: pr.exerciseName,
        recordType: pr.recordType,
        value: pr.value,
        achievedAt: pr.achievedAt,
        estimatedOneRm: estimatedOneRm,
        rpe: rpe,
        athleteName: athleteName,
      );

  factory PrCardData.fromProgressPr(
    ProgressPersonalRecord pr, {
    String? athleteName,
  }) =>
      PrCardData(
        exerciseName: pr.exerciseName,
        recordType: pr.recordType,
        value: pr.value,
        achievedAt: DateTime.parse(pr.achievedAt),
        athleteName: athleteName,
      );
}
