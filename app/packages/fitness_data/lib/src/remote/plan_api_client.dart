import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/plan_dtos.dart';

part 'plan_api_client.g.dart';

@RestApi()
abstract class PlanApiClient {
  factory PlanApiClient(Dio dio) = _PlanApiClient;

  @GET('/api/v1/plans')
  Future<PlanListEnvelopeDto> listPlans({
    @Query('cursor') String? cursor,
    @Query('limit') int? limit,
  });

  @GET('/api/v1/plans/{id}')
  Future<PlanDetailEnvelopeDto> getPlan(@Path('id') String id);
}
