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

  @GET('/plans')
  Future<PlanListEnvelopeDto> listPlans({
    @Query('cursor') String? cursor,
    @Query('limit') int? limit,
  });

  @GET('/plans/{id}')
  Future<PlanDetailEnvelopeDto> getPlan(@Path('id') String id);

  // -------------------------------------------------------------------------
  // Write — plan metadata
  // -------------------------------------------------------------------------

  @POST('/plans')
  Future<PlanDetailEnvelopeDto> createPlan(
      @Body() CreatePlanRequestDto body);

  @PATCH('/plans/{id}')
  Future<PlanDetailEnvelopeDto> updatePlan(
    @Path('id') String id,
    @Body() UpdatePlanRequestDto body,
  );

  @DELETE('/plans/{id}')
  Future<void> deletePlan(@Path('id') String id);

  // -------------------------------------------------------------------------
  // Write — plan day metadata (isDeload, name)
  // -------------------------------------------------------------------------

  @PATCH('/plans/{planId}/days/{dayId}')
  Future<PlanDayUpdateEnvelopeDto> updatePlanDay(
    @Path('planId') String planId,
    @Path('dayId') String dayId,
    @Body() UpdatePlanDayRequestDto body,
  );

  // -------------------------------------------------------------------------
  // Write — exercises within a plan day
  // -------------------------------------------------------------------------

  @POST('/plans/{id}/exercises')
  Future<PlanDetailEnvelopeDto> addExercise(
    @Path('id') String planId,
    @Body() AddPlanExerciseRequestDto body,
  );

  @PATCH('/plans/{id}/exercises/{exId}')
  Future<PlanDetailEnvelopeDto> updateExercise(
    @Path('id') String planId,
    @Path('exId') String exerciseId,
    @Body() UpdatePlanExerciseRequestDto body,
  );

  @DELETE('/plans/{id}/exercises/{exId}')
  Future<void> deleteExercise(
    @Path('id') String planId,
    @Path('exId') String exerciseId,
  );

  @PATCH('/plans/{id}/exercises/reorder')
  Future<void> reorderExercises(
    @Path('id') String planId,
    @Body() ReorderPlanExercisesRequestDto body,
  );

  // -------------------------------------------------------------------------
  // Templates
  // -------------------------------------------------------------------------

  @GET('/plans/templates')
  Future<TemplateListEnvelopeDto> listTemplates({
    @Query('category') String? category,
  });

  @GET('/plans/templates/{templateId}')
  Future<TemplateDetailEnvelopeDto> getTemplate(
    @Path('templateId') String templateId,
  );

  @POST('/plans/templates/{templateId}/import')
  Future<PlanDetailEnvelopeDto> importTemplate(
    @Path('templateId') String templateId,
    @Body() ImportTemplateRequestDto body,
  );
}
