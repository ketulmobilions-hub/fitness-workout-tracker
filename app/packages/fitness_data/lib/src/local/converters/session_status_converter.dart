import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

enum SessionStatus {
  inProgress,
  completed,
  abandoned,
}

class SessionStatusConverter extends TypeConverter<SessionStatus, String> {
  const SessionStatusConverter();

  @override
  SessionStatus fromSql(String fromDb) {
    switch (fromDb) {
      case 'in_progress':
        return SessionStatus.inProgress;
      case 'completed':
        return SessionStatus.completed;
      case 'abandoned':
        return SessionStatus.abandoned;
      default:
        debugPrint('SessionStatusConverter: unknown value "$fromDb", falling back to abandoned');
        return SessionStatus.abandoned;
    }
  }

  @override
  String toSql(SessionStatus value) {
    switch (value) {
      case SessionStatus.inProgress:
        return 'in_progress';
      case SessionStatus.completed:
        return 'completed';
      case SessionStatus.abandoned:
        return 'abandoned';
    }
  }
}
