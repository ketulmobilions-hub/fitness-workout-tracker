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

  @GET('/api/v1/sessions')
  Future<SessionListEnvelopeDto> listSessions({
    @Query('status') String? status,
    @Query('cursor') String? cursor,
    @Query('limit') int? limit,
    @Query('from') String? from,
    @Query('to') String? to,
  });

  @POST('/api/v1/sessions')
  Future<SessionDetailEnvelopeDto> startSession(
      @Body() StartSessionRequestDto body);

  @GET('/api/v1/sessions/{id}')
  Future<SessionDetailEnvelopeDto> getSession(@Path('id') String id);

  @PATCH('/api/v1/sessions/{id}')
  Future<SessionDetailEnvelopeDto> updateSession(
    @Path('id') String id,
    @Body() UpdateSessionRequestDto body,
  );

  @POST('/api/v1/sessions/{id}/complete')
  Future<CompleteSessionEnvelopeDto> completeSession(
    @Path('id') String id,
    @Body() CompleteSessionRequestDto body,
  );

  // -------------------------------------------------------------------------
  // Set logging
  // -------------------------------------------------------------------------

  @POST('/api/v1/sessions/{id}/sets')
  Future<LogSetEnvelopeDto> logSet(
    @Path('id') String sessionId,
    @Body() LogSetRequestDto body,
  );

  @DELETE('/api/v1/sessions/{id}/sets/{setId}')
  Future<void> deleteSet(
    @Path('id') String sessionId,
    @Path('setId') String setId,
  );
}
