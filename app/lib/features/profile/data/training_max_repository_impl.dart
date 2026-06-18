import 'package:dio/dio.dart';
import 'package:fitness_data/fitness_data.dart' as data;
import 'package:fitness_domain/fitness_domain.dart';

class TrainingMaxRepositoryImpl implements TrainingMaxRepository {
  TrainingMaxRepositoryImpl({required data.TrainingMaxApiClient apiClient})
      : _apiClient = apiClient;

  final data.TrainingMaxApiClient _apiClient;

  @override
  Future<List<TrainingMax>> fetchAll() async {
    try {
      final envelope = await _apiClient.getTrainingMaxes();
      return envelope.data.map(_mapDto).toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<TrainingMax> upsert({
    required String exerciseId,
    required double trainingMaxKg,
    required double percentageOf1rm,
  }) async {
    try {
      final envelope = await _apiClient.upsertTrainingMax(
        exerciseId,
        {
          'trainingMaxKg': trainingMaxKg,
          'percentageOf1rm': percentageOf1rm,
        },
      );
      return _mapDto(envelope.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  TrainingMax _mapDto(data.TrainingMaxDto dto) => TrainingMax(
        id: dto.id,
        exerciseId: dto.exerciseId,
        exerciseName: dto.exerciseName,
        exerciseType: dto.exerciseType,
        trainingMaxKg: dto.trainingMaxKg,
        percentageOf1rm: dto.percentageOf1rm,
        latestPrKg: dto.latestPrKg,
        latestPrDate:
            dto.latestPrDate != null ? DateTime.parse(dto.latestPrDate!) : null,
        updatedAt: DateTime.parse(dto.updatedAt),
      );

  Exception _mapError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404) return Exception('Exercise not found');
    if (status == 401) return Exception('Unauthorised');
    return Exception('Failed to update training max: ${e.message}');
  }
}
