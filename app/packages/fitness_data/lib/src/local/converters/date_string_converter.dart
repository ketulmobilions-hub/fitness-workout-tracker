import 'package:drift/drift.dart';

/// Stores a [DateTime] as a `YYYY-MM-DD` text string in SQLite.
///
/// Using a full [DateTimeColumn] (Unix timestamp) for calendar dates causes the
/// `UNIQUE (user_id, date)` constraint on [StreakHistory] to be ineffective:
/// two timestamps on the same calendar day have different integer values and
/// would not be caught by the constraint. Storing as ISO date text ensures
/// uniqueness works correctly.
class DateStringConverter extends TypeConverter<DateTime, String> {
  const DateStringConverter();

  @override
  DateTime fromSql(String fromDb) {
    // Parse YYYY-MM-DD and return midnight UTC
    final parts = fromDb.split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  String toSql(DateTime value) {
    // Normalize to YYYY-MM-DD (local date, zero-padded)
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
