import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_request_dtos.freezed.dart';
part 'auth_request_dtos.g.dart';

@freezed
abstract class LoginRequestDto with _$LoginRequestDto {
  const factory LoginRequestDto({
    required String email,
    required String password,
  }) = _LoginRequestDto;

  factory LoginRequestDto.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestDtoFromJson(json);
}

@freezed
abstract class RegisterRequestDto with _$RegisterRequestDto {
  const factory RegisterRequestDto({
    required String email,
    required String password,
    @JsonKey(includeIfNull: false) String? displayName,
  }) = _RegisterRequestDto;

  factory RegisterRequestDto.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestDtoFromJson(json);
}

@freezed
abstract class ForgotPasswordRequestDto with _$ForgotPasswordRequestDto {
  const factory ForgotPasswordRequestDto({
    required String email,
  }) = _ForgotPasswordRequestDto;

  factory ForgotPasswordRequestDto.fromJson(Map<String, dynamic> json) =>
      _$ForgotPasswordRequestDtoFromJson(json);
}

@freezed
abstract class ResetPasswordRequestDto with _$ResetPasswordRequestDto {
  const factory ResetPasswordRequestDto({
    required String token,
    required String newPassword,
  }) = _ResetPasswordRequestDto;

  factory ResetPasswordRequestDto.fromJson(Map<String, dynamic> json) =>
      _$ResetPasswordRequestDtoFromJson(json);
}

@freezed
abstract class GoogleSignInRequestDto with _$GoogleSignInRequestDto {
  const factory GoogleSignInRequestDto({
    required String idToken,
  }) = _GoogleSignInRequestDto;

  factory GoogleSignInRequestDto.fromJson(Map<String, dynamic> json) =>
      _$GoogleSignInRequestDtoFromJson(json);
}

@freezed
abstract class AppleSignInRequestDto with _$AppleSignInRequestDto {
  const factory AppleSignInRequestDto({
    required String identityToken,
    @JsonKey(includeIfNull: false) String? displayName,
  }) = _AppleSignInRequestDto;

  factory AppleSignInRequestDto.fromJson(Map<String, dynamic> json) =>
      _$AppleSignInRequestDtoFromJson(json);
}
