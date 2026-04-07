import 'package:drift/drift.dart';

import '../converters/exercise_type_converter.dart';
import 'users_table.dart';

@DataClassName('MuscleGroupRow')
class MuscleGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get bodyRegion => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ExerciseRow')
class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get exerciseType =>
      text().map(const ExerciseTypeConverter())();
  TextColumn get instructions => text().nullable()();
  TextColumn get mediaUrl => text().nullable()();
  TextColumn get createdBy =>
      text().nullable().references(Users, #id)();
  BoolColumn get isCustom =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ExerciseMuscleGroupRow')
class ExerciseMuscleGroups extends Table {
  TextColumn get exerciseId => text().references(Exercises, #id)();
  TextColumn get muscleGroupId =>
      text().references(MuscleGroups, #id)();
  BoolColumn get isPrimary =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {exerciseId, muscleGroupId};
}
