import 'package:drift/drift.dart';

import '../converters/date_string_converter.dart';
import '../converters/record_type_converter.dart';
import '../converters/streak_day_status_converter.dart';
import 'exercise_library_tables.dart';
import 'users_table.dart';
import 'workout_session_tables.dart';

@DataClassName('PersonalRecordRow')
class PersonalRecords extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  TextColumn get recordType =>
      text().map(const RecordTypeConverter())();
  RealColumn get value => real()();
  DateTimeColumn get achievedAt => dateTime()();
  TextColumn get sessionId =>
      text().nullable().references(WorkoutSessions, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StreakRow')
class Streaks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().unique().references(Users, #id)();
  IntColumn get currentStreak =>
      integer().withDefault(const Constant(0))();
  IntColumn get longestStreak =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastWorkoutDate => dateTime().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StreakHistoryRow')
class StreakHistory extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  // Stored as YYYY-MM-DD text so the UNIQUE(user_id, date) constraint
  // correctly enforces one entry per calendar day (Unix timestamps for the
  // same day differ and would not be caught by a timestamp-based constraint).
  TextColumn get date => text().map(const DateStringConverter())();
  TextColumn get status =>
      text().map(const StreakDayStatusConverter())();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (user_id, date)'];
}
