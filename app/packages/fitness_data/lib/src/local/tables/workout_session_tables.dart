import 'package:drift/drift.dart';

import '../converters/session_status_converter.dart';
import 'exercise_library_tables.dart';
import 'users_table.dart';
import 'workout_plan_tables.dart';

@DataClassName('WorkoutSessionRow')
class WorkoutSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get planId =>
      text().nullable().references(WorkoutPlans, #id)();
  TextColumn get planDayId =>
      text().nullable().references(PlanDays, #id)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get durationSec => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status =>
      text().map(const SessionStatusConverter())();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ExerciseLogRow')
class ExerciseLogs extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(WorkoutSessions, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get sortOrder => integer()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SetLogRow')
class SetLogs extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseLogId =>
      text().references(ExerciseLogs, #id)();
  IntColumn get setNumber => integer()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get durationSec => integer().nullable()();
  RealColumn get distanceM => real().nullable()();
  RealColumn get paceSecPerKm => real().nullable()();
  IntColumn get heartRate => integer().nullable()();
  IntColumn get rpe => integer().nullable()();
  TextColumn get tempo => text().nullable()();
  BoolColumn get isWarmup =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
