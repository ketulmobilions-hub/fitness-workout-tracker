import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

enum ScheduleType {
  weekly,
  recurring,
}

class ScheduleTypeConverter extends TypeConverter<ScheduleType, String> {
  const ScheduleTypeConverter();

  @override
  ScheduleType fromSql(String fromDb) {
    switch (fromDb) {
      case 'weekly':
        return ScheduleType.weekly;
      case 'recurring':
        return ScheduleType.recurring;
      default:
        debugPrint('ScheduleTypeConverter: unknown value "$fromDb", falling back to weekly');
        return ScheduleType.weekly;
    }
  }

  @override
  String toSql(ScheduleType value) {
    switch (value) {
      case ScheduleType.weekly:
        return 'weekly';
      case ScheduleType.recurring:
        return 'recurring';
    }
  }
}
