import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_response_dtos.freezed.dart';
part 'auth_response_dtos.g.dart';

@freezed
abstract class AuthUserDto with _$AuthUserDto {
  const factory AuthUserDto({
    required String id,
    // email is nullable: guest accounts omit it; Apple omits it after the
    // first sign-in. A nullable String? field deserializes to null when the
    // key is absent from JSON, so no annotation is needed.
    String? email,
    String? displayName,
  }) = _AuthUserDto;

  factory AuthUserDto.fromJson(Map<String, dynamic> json) =>
      _$AuthUserDtoFromJson(json);
}

@freezed
abstract class AuthResponseDto with _$AuthResponseDto {
  const factory AuthResponseDto({
    required AuthUserDto user,
    required String accessToken,
    required String refreshToken,
  }) = _AuthResponseDto;

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseDtoFromJson(json);
}

@freezed
abstract class AuthEnvelopeDto with _$AuthEnvelopeDto {
  const factory AuthEnvelopeDto({
    required AuthResponseDto data,
  }) = _AuthEnvelopeDto;

  factory AuthEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$AuthEnvelopeDtoFromJson(json);
}

@freezed
abstract class RefreshResponseDto with _$RefreshResponseDto {
  const factory RefreshResponseDto({
    required String accessToken,
    required String refreshToken,
  }) = _RefreshResponseDto;

  factory RefreshResponseDto.fromJson(Map<String, dynamic> json) =>
      _$RefreshResponseDtoFromJson(json);
}

@freezed
abstract class RefreshEnvelopeDto with _$RefreshEnvelopeDto {
  const factory RefreshEnvelopeDto({
    required RefreshResponseDto data,
  }) = _RefreshEnvelopeDto;

  factory RefreshEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$RefreshEnvelopeDtoFromJson(json);
}

@freezed
abstract class MessageResponseDto with _$MessageResponseDto {
  const factory MessageResponseDto({
    required String message,
  }) = _MessageResponseDto;

  factory MessageResponseDto.fromJson(Map<String, dynamic> json) =>
      _$MessageResponseDtoFromJson(json);
}

@freezed
abstract class MessageEnvelopeDto with _$MessageEnvelopeDto {
  const factory MessageEnvelopeDto({
    required MessageResponseDto data,
  }) = _MessageEnvelopeDto;

  factory MessageEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$MessageEnvelopeDtoFromJson(json);
}
