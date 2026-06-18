import 'training_max.dart';

abstract class TrainingMaxRepository {
  Future<List<TrainingMax>> fetchAll();
  Future<TrainingMax> upsert({
    required String exerciseId,
    required double trainingMaxKg,
    required double percentageOf1rm,
  });
}
