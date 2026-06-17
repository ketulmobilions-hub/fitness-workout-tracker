import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/plan_dtos.dart';
import 'dtos/plan_request_dtos.dart';
import 'dtos/template_dtos.dart';

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
  // Write — plan day metadata (isDeload, name)
  // -------------------------------------------------------------------------

  @PATCH('/api/v1/plans/{planId}/days/{dayId}')
  Future<PlanDayUpdateEnvelopeDto> updatePlanDay(
    @Path('planId') String planId,
    @Path('dayId') String dayId,
    @Body() UpdatePlanDayRequestDto body,
  );

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

  // -------------------------------------------------------------------------
  // Templates
  // -------------------------------------------------------------------------

  @GET('/api/v1/plans/templates')
  Future<TemplateListEnvelopeDto> listTemplates({
    @Query('category') String? category,
  });

  @GET('/api/v1/plans/templates/{templateId}')
  Future<TemplateDetailEnvelopeDto> getTemplate(
    @Path('templateId') String templateId,
  );

  @POST('/api/v1/plans/templates/{templateId}/import')
  Future<PlanDetailEnvelopeDto> importTemplate(
    @Path('templateId') String templateId,
    @Body() ImportTemplateRequestDto body,
  );
}
