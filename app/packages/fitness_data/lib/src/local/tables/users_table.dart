import 'package:drift/drift.dart';

import '../converters/auth_provider_converter.dart';
import '../converters/json_string_converter.dart';

@DataClassName('UserRow')
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().unique()();
  TextColumn get passwordHash => text().nullable()();
  TextColumn get displayName => text()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get bio => text().nullable()();
  TextColumn get authProvider =>
      text().map(const AuthProviderConverter())();
  BoolColumn get isGuest =>
      boolean().withDefault(const Constant(false))();
  TextColumn get preferences =>
      text().map(const JsonStringConverter()).withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
