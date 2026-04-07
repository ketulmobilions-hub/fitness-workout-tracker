import 'package:drift/drift.dart';

import '../converters/json_string_converter.dart';
import '../converters/sync_operation_converter.dart';
import 'users_table.dart';

@DataClassName('SyncQueueRow')
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get entityTable => text().named('table_name')();
  TextColumn get recordId => text()();
  TextColumn get operation =>
      text().map(const SyncOperationConverter())();
  TextColumn get payload => text().map(const JsonStringConverter())();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  // Retry tracking — allows the sync engine to implement exponential backoff
  // and skip permanently-failing items rather than blocking the queue.
  IntColumn get retryCount =>
      integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get failedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
