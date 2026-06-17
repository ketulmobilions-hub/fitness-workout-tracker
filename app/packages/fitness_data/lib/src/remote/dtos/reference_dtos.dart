import 'package:freezed_annotation/freezed_annotation.dart';

part 'reference_dtos.freezed.dart';
part 'reference_dtos.g.dart';

@freezed
abstract class WeightClassesEnvelopeDto with _$WeightClassesEnvelopeDto {
  const factory WeightClassesEnvelopeDto({
    // weightClasses: { federation: { gender: [kg, ...] } }
    // Stored as dynamic because nested Map<String, List<num>> can't be
    // auto-deserialized by json_serializable without a custom converter.
    required Map<String, dynamic> data,
  }) = _WeightClassesEnvelopeDto;

  factory WeightClassesEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      _$WeightClassesEnvelopeDtoFromJson(json);
}
