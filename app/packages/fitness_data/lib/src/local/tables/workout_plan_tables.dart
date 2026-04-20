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
  // weekNumber is non-nullable in SQLite. The value 0 is used as a sentinel
  // meaning "no week applies" (i.e., a weekly / single-week plan where the
  // concept of a week number is irrelevant). For recurring multi-week plans
  // the server uses 1-based week numbers (1 = first week), so 0 is always
  // unambiguous as the "not set" sentinel. The domain layer maps 0 → null and
  // null → 0 at the sync boundary (see WorkoutPlanRepositoryImpl).
  //
  // A cleaner long-term fix is to make this column nullable and run a table-
  // recreation migration, but that is deferred until there is production data
  // that warrants the complexity.
  IntColumn get weekNumber => integer()();
  TextColumn get name => text().nullable()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

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
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
