import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

enum RecordType {
  maxWeight,
  maxReps,
  maxVolume,
  bestPace,
}

class RecordTypeConverter extends TypeConverter<RecordType, String> {
  const RecordTypeConverter();

  @override
  RecordType fromSql(String fromDb) {
    switch (fromDb) {
      case 'max_weight':
        return RecordType.maxWeight;
      case 'max_reps':
        return RecordType.maxReps;
      case 'max_volume':
        return RecordType.maxVolume;
      case 'best_pace':
        return RecordType.bestPace;
      default:
        debugPrint('RecordTypeConverter: unknown value "$fromDb", falling back to maxWeight');
        return RecordType.maxWeight;
    }
  }

  @override
  String toSql(RecordType value) {
    switch (value) {
      case RecordType.maxWeight:
        return 'max_weight';
      case RecordType.maxReps:
        return 'max_reps';
      case RecordType.maxVolume:
        return 'max_volume';
      case RecordType.bestPace:
        return 'best_pace';
    }
  }
}
