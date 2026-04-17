import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/progress_dtos.dart';

part 'progress_api_client.g.dart';

@RestApi()
abstract class ProgressApiClient {
  factory ProgressApiClient(Dio dio) = _ProgressApiClient;

  @GET('/api/v1/progress/overview')
  Future<ProgressOverviewEnvelopeDto> getOverview({
    @Query('utc_offset') required int utcOffset,
  });

  @GET('/api/v1/progress/exercise/{id}')
  Future<ExerciseProgressEnvelopeDto> getExerciseProgress(
    @Path('id') String id, {
    @Query('period') required String period,
  });

  @GET('/api/v1/progress/personal-records')
  Future<PersonalRecordsEnvelopeDto> getPersonalRecords({
    @Query('exercise_id') String? exerciseId,
    @Query('record_type') String? recordType,
  });

  @GET('/api/v1/progress/volume')
  Future<VolumeEnvelopeDto> getVolume({
    @Query('period') required String period,
    @Query('granularity') String? granularity,
  });
}
