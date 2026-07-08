import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/progress_dtos.dart';

part 'progress_api_client.g.dart';

@RestApi()
abstract class ProgressApiClient {
  factory ProgressApiClient(Dio dio) = _ProgressApiClient;

  @GET('/progress/overview')
  Future<ProgressOverviewEnvelopeDto> getOverview({
    @Query('utc_offset') required int utcOffset,
  });

  @GET('/progress/exercise/{id}')
  Future<ExerciseProgressEnvelopeDto> getExerciseProgress(
    @Path('id') String id, {
    @Query('period') required String period,
  });

  @GET('/progress/personal-records')
  Future<PersonalRecordsEnvelopeDto> getPersonalRecords({
    @Query('exercise_id') String? exerciseId,
    @Query('record_type') String? recordType,
  });

  @GET('/progress/volume')
  Future<VolumeEnvelopeDto> getVolume({
    @Query('period') required String period,
    @Query('granularity') String? granularity,
  });

  @GET('/progress/sbd-total')
  Future<SbdTotalEnvelopeDto> getSbdTotal();

  @GET('/progress/strength-scores/history')
  Future<ScoreHistoryEnvelopeDto> getStrengthScoreHistory();

  @GET('/progress/volume-zones')
  Future<VolumeZoneEnvelopeDto> getVolumeZones({
    @Query('weeks') int? weeks,
    @Query('utc_offset') required int utcOffset,
  });
}
