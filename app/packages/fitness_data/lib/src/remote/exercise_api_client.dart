import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/exercise_dtos.dart';

part 'exercise_api_client.g.dart';

@RestApi()
abstract class ExerciseApiClient {
  factory ExerciseApiClient(Dio dio) = _ExerciseApiClient;

  @GET('/api/v1/exercises')
  Future<ExerciseListEnvelopeDto> listExercises({
    @Query('search') String? search,
    @Query('exercise_type') String? exerciseType,
    @Query('muscle_group') String? muscleGroup,
    @Query('cursor') String? cursor,
    @Query('limit') int? limit,
  });

  @GET('/api/v1/exercises/{id}')
  Future<ExerciseDetailEnvelopeDto> getExercise(@Path('id') String id);

  @POST('/api/v1/exercises')
  Future<ExerciseDetailEnvelopeDto> createExercise(
    @Body() CreateExerciseRequestDto body,
  );

  @DELETE('/api/v1/exercises/{id}')
  Future<void> deleteExercise(@Path('id') String id);

  @GET('/api/v1/muscle-groups')
  Future<MuscleGroupListEnvelopeDto> getMuscleGroups();
}
