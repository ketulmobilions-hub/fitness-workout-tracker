import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/competition_dtos.dart';

part 'competition_api_client.g.dart';

@RestApi()
abstract class CompetitionApiClient {
  factory CompetitionApiClient(Dio dio) = _CompetitionApiClient;

  @GET('/api/v1/competitions')
  Future<CompetitionListEnvelopeDto> listCompetitions();

  @POST('/api/v1/competitions')
  Future<CompetitionEnvelopeDto> createCompetition(
    @Body() Map<String, dynamic> body,
  );

  @GET('/api/v1/competitions/{id}')
  Future<CompetitionEnvelopeDto> getCompetition(@Path('id') String id);

  @PATCH('/api/v1/competitions/{id}')
  Future<CompetitionUpdateEnvelopeDto> updateCompetition(
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  @POST('/api/v1/competitions/{id}/attempts')
  Future<CompetitionAttemptEnvelopeDto> logAttempt(
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );
}
