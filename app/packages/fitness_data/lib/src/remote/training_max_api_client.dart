import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/training_max_dtos.dart';

part 'training_max_api_client.g.dart';

@RestApi()
abstract class TrainingMaxApiClient {
  factory TrainingMaxApiClient(Dio dio) = _TrainingMaxApiClient;

  @GET('/api/v1/training-maxes')
  Future<TrainingMaxListEnvelopeDto> getTrainingMaxes();

  @PUT('/api/v1/training-maxes/{exerciseId}')
  Future<TrainingMaxEnvelopeDto> upsertTrainingMax(
    @Path('exerciseId') String exerciseId,
    @Body() Map<String, dynamic> body,
  );
}
