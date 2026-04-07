import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

enum StreakDayStatus {
  completed,
  restDay,
  missed,
}

class StreakDayStatusConverter extends TypeConverter<StreakDayStatus, String> {
  const StreakDayStatusConverter();

  @override
  StreakDayStatus fromSql(String fromDb) {
    switch (fromDb) {
      case 'completed':
        return StreakDayStatus.completed;
      case 'rest_day':
        return StreakDayStatus.restDay;
      case 'missed':
        return StreakDayStatus.missed;
      default:
        debugPrint('StreakDayStatusConverter: unknown value "$fromDb", falling back to missed');
        return StreakDayStatus.missed;
    }
  }

  @override
  String toSql(StreakDayStatus value) {
    switch (value) {
      case StreakDayStatus.completed:
        return 'completed';
      case StreakDayStatus.restDay:
        return 'rest_day';
      case StreakDayStatus.missed:
        return 'missed';
    }
  }
}
