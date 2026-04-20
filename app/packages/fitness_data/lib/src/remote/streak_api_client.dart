import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/streak_dtos.dart';

part 'streak_api_client.g.dart';

@RestApi()
abstract class StreakApiClient {
  factory StreakApiClient(Dio dio) = _StreakApiClient;

  @GET('/api/v1/streaks')
  Future<StreakEnvelopeDto> getStreak();

  @GET('/api/v1/streaks/history')
  Future<StreakHistoryEnvelopeDto> getStreakHistory({
    @Query('year') required int year,
    @Query('month') required int month,
  });
}
