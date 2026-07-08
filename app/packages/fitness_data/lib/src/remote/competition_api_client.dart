import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/competition_dtos.dart';

part 'competition_api_client.g.dart';

@RestApi()
abstract class CompetitionApiClient {
  factory CompetitionApiClient(Dio dio) = _CompetitionApiClient;

  @GET('/competitions')
  Future<CompetitionListEnvelopeDto> listCompetitions();

  @POST('/competitions')
  Future<CompetitionEnvelopeDto> createCompetition(
    @Body() Map<String, dynamic> body,
  );

  @GET('/competitions/{id}')
  Future<CompetitionEnvelopeDto> getCompetition(@Path('id') String id);

  @PATCH('/competitions/{id}')
  Future<CompetitionUpdateEnvelopeDto> updateCompetition(
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  @POST('/competitions/{id}/attempts')
  Future<CompetitionAttemptEnvelopeDto> logAttempt(
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );
}
