import 'package:freezed_annotation/freezed_annotation.dart';

part 'training_max.freezed.dart';

@freezed
abstract class TrainingMax with _$TrainingMax {
  const factory TrainingMax({
    required String id,
    required String exerciseId,
    required String exerciseName,
    required String exerciseType,
    required double trainingMaxKg,
    required double percentageOf1rm,
    double? latestPrKg,
    DateTime? latestPrDate,
    required DateTime updatedAt,
  }) = _TrainingMax;
}
