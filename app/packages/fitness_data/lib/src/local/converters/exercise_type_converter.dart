import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:fitness_domain/fitness_domain.dart';

// Re-export so existing code that imports this file still gets ExerciseType.
export 'package:fitness_domain/fitness_domain.dart' show ExerciseType;

class ExerciseTypeConverter extends TypeConverter<ExerciseType, String> {
  const ExerciseTypeConverter();

  @override
  ExerciseType fromSql(String fromDb) {
    switch (fromDb) {
      case 'strength':
        return ExerciseType.strength;
      case 'cardio':
        return ExerciseType.cardio;
      case 'stretching':
        return ExerciseType.stretching;
      default:
        debugPrint('ExerciseTypeConverter: unknown value "$fromDb", falling back to strength');
        return ExerciseType.strength;
    }
  }

  @override
  String toSql(ExerciseType value) {
    switch (value) {
      case ExerciseType.strength:
        return 'strength';
      case ExerciseType.cardio:
        return 'cardio';
      case ExerciseType.stretching:
        return 'stretching';
    }
  }
}
