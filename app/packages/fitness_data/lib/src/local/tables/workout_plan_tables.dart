import 'package:drift/drift.dart';

import '../converters/schedule_type_converter.dart';
import 'exercise_library_tables.dart';
import 'users_table.dart';

@DataClassName('WorkoutPlanRow')
class WorkoutPlans extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  TextColumn get scheduleType =>
      text().map(const ScheduleTypeConverter())();
  IntColumn get weeksCount => integer().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlanDayRow')
class PlanDays extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(WorkoutPlans, #id)();
  IntColumn get dayOfWeek => integer()();
  IntColumn get weekNumber => integer()();
  TextColumn get name => text().nullable()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlanDayExerciseRow')
class PlanDayExercises extends Table {
  TextColumn get id => text()();
  TextColumn get planDayId => text().references(PlanDays, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get sortOrder => integer()();
  IntColumn get targetSets => integer().nullable()();
  // Stored as text (e.g. "8-12") to support ranges
  TextColumn get targetReps => text().nullable()();
  IntColumn get targetDurationSec => integer().nullable()();
  RealColumn get targetDistanceM => real().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
