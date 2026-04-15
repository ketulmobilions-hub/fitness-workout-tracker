import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/plan_dtos.dart';
import 'dtos/plan_request_dtos.dart';

part 'plan_api_client.g.dart';

@RestApi()
abstract class PlanApiClient {
  factory PlanApiClient(Dio dio) = _PlanApiClient;

  // -------------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------------

  @GET('/api/v1/plans')
  Future<PlanListEnvelopeDto> listPlans({
    @Query('cursor') String? cursor,
    @Query('limit') int? limit,
  });

  @GET('/api/v1/plans/{id}')
  Future<PlanDetailEnvelopeDto> getPlan(@Path('id') String id);

  // -------------------------------------------------------------------------
  // Write — plan metadata
  // -------------------------------------------------------------------------

  @POST('/api/v1/plans')
  Future<PlanDetailEnvelopeDto> createPlan(
      @Body() CreatePlanRequestDto body);

  @PATCH('/api/v1/plans/{id}')
  Future<PlanDetailEnvelopeDto> updatePlan(
    @Path('id') String id,
    @Body() UpdatePlanRequestDto body,
  );

  @DELETE('/api/v1/plans/{id}')
  Future<void> deletePlan(@Path('id') String id);

  // -------------------------------------------------------------------------
  // Write — exercises within a plan day
  // -------------------------------------------------------------------------

  @POST('/api/v1/plans/{id}/exercises')
  Future<PlanDetailEnvelopeDto> addExercise(
    @Path('id') String planId,
    @Body() AddPlanExerciseRequestDto body,
  );

  @PATCH('/api/v1/plans/{id}/exercises/{exId}')
  Future<PlanDetailEnvelopeDto> updateExercise(
    @Path('id') String planId,
    @Path('exId') String exerciseId,
    @Body() UpdatePlanExerciseRequestDto body,
  );

  @DELETE('/api/v1/plans/{id}/exercises/{exId}')
  Future<void> deleteExercise(
    @Path('id') String planId,
    @Path('exId') String exerciseId,
  );

  @PATCH('/api/v1/plans/{id}/exercises/reorder')
  Future<void> reorderExercises(
    @Path('id') String planId,
    @Body() ReorderPlanExercisesRequestDto body,
  );
}
