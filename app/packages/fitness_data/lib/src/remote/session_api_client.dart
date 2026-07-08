import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/session_dtos.dart';
import 'dtos/session_list_dto.dart';
import 'dtos/session_request_dtos.dart';

part 'session_api_client.g.dart';

@RestApi()
abstract class SessionApiClient {
  factory SessionApiClient(Dio dio) = _SessionApiClient;

  // -------------------------------------------------------------------------
  // Session lifecycle
  // -------------------------------------------------------------------------

  @GET('/sessions')
  Future<SessionListEnvelopeDto> listSessions({
    @Query('status') String? status,
    @Query('cursor') String? cursor,
    @Query('limit') int? limit,
    @Query('from') String? from,
    @Query('to') String? to,
  });

  @POST('/sessions')
  Future<StartSessionEnvelopeDto> startSession(
      @Body() StartSessionRequestDto body);

  @GET('/sessions/{id}')
  Future<SessionDetailEnvelopeDto> getSession(@Path('id') String id);

  @PATCH('/sessions/{id}')
  Future<SessionDetailEnvelopeDto> updateSession(
    @Path('id') String id,
    @Body() UpdateSessionRequestDto body,
  );

  @POST('/sessions/{id}/complete')
  Future<CompleteSessionEnvelopeDto> completeSession(
    @Path('id') String id,
    @Body() CompleteSessionRequestDto body,
  );

  // -------------------------------------------------------------------------
  // Set logging
  // -------------------------------------------------------------------------

  @POST('/sessions/{id}/sets')
  Future<LogSetEnvelopeDto> logSet(
    @Path('id') String sessionId,
    @Body() LogSetRequestDto body,
  );

  @DELETE('/sessions/{id}/sets/{setId}')
  Future<void> deleteSet(
    @Path('id') String sessionId,
    @Path('setId') String setId,
  );

  // -------------------------------------------------------------------------
  // RPE-to-weight suggestion
  // -------------------------------------------------------------------------

  @GET('/sessions/suggest-weight')
  Future<RpeSuggestionEnvelopeDto> suggestWeight({
    @Query('exerciseId') required String exerciseId,
    @Query('targetRpe') required double targetRpe,
  });
}
