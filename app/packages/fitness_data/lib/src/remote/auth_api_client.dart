import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/auth_request_dtos.dart';
import 'dtos/auth_response_dtos.dart';

part 'auth_api_client.g.dart';

@RestApi()
abstract class AuthApiClient {
  factory AuthApiClient(Dio dio) = _AuthApiClient;

  @POST('/auth/login')
  Future<AuthEnvelopeDto> login(@Body() LoginRequestDto body);

  @POST('/auth/register')
  Future<AuthEnvelopeDto> register(@Body() RegisterRequestDto body);

  @POST('/auth/refresh')
  Future<RefreshEnvelopeDto> refreshToken(
    @Body() Map<String, String> body,
  );

  @POST('/auth/forgot-password')
  Future<MessageEnvelopeDto> forgotPassword(
    @Body() ForgotPasswordRequestDto body,
  );

  @POST('/auth/reset-password')
  Future<MessageEnvelopeDto> resetPassword(
    @Body() ResetPasswordRequestDto body,
  );

  @POST('/auth/google')
  Future<AuthEnvelopeDto> googleSignIn(
    @Body() GoogleSignInRequestDto body,
  );

  @POST('/auth/apple')
  Future<AuthEnvelopeDto> appleSignIn(
    @Body() AppleSignInRequestDto body,
  );

  @POST('/auth/guest')
  Future<AuthEnvelopeDto> guestSignIn();
}
