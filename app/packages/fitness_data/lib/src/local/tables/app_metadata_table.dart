import 'package:drift/drift.dart';

/// Simple key/value store for small pieces of app-wide state that must survive
/// restarts but do not belong to any domain table — e.g. the timestamp of the
/// last successful exercise-catalog sync used to throttle re-syncing.
@DataClassName('AppMetadataRow')
class AppMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
