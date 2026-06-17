import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/reference_dtos.dart';

part 'reference_api_client.g.dart';

@RestApi()
abstract class ReferenceApiClient {
  factory ReferenceApiClient(Dio dio) = _ReferenceApiClient;

  @GET('/reference/weight-classes')
  Future<WeightClassesEnvelopeDto> getWeightClasses();
}
