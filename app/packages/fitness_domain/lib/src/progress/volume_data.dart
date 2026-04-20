import 'package:freezed_annotation/freezed_annotation.dart';

part 'volume_data.freezed.dart';

@freezed
abstract class VolumeBucket with _$VolumeBucket {
  const factory VolumeBucket({
    required String date,
    required double volume,
    required int sessions,
  }) = _VolumeBucket;
}

@freezed
abstract class VolumeData with _$VolumeData {
  const factory VolumeData({
    required String granularity,
    @Default([]) List<VolumeBucket> buckets,
  }) = _VolumeData;
}
