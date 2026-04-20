import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/profile_dtos.dart';

part 'user_api_client.g.dart';

@RestApi()
abstract class UserApiClient {
  factory UserApiClient(Dio dio) = _UserApiClient;

  @GET('/users/me')
  Future<ProfileEnvelopeDto> getProfile();

  @PATCH('/users/me')
  Future<ProfileEnvelopeDto> updateProfile(
    @Body() UpdateProfileRequestDto body,
  );

  @PATCH('/users/me/preferences')
  Future<PreferencesEnvelopeDto> updatePreferences(
    @Body() UpdatePreferencesRequestDto body,
  );

  @GET('/users/me/stats')
  Future<StatsEnvelopeDto> getStats();

  @DELETE('/users/me')
  Future<void> deleteAccount();
}
