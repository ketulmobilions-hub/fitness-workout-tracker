import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:fitness_domain/fitness_domain.dart';

// Re-export so existing code that imports this file still gets SessionStatus.
export 'package:fitness_domain/fitness_domain.dart' show SessionStatus;

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
        // Fall back to inProgress — safer than abandoned since an inProgress
        // session can still be resumed. Corrected on next full sync.
        debugPrint('SessionStatusConverter: unknown value "$fromDb", falling back to inProgress');
        return SessionStatus.inProgress;
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
