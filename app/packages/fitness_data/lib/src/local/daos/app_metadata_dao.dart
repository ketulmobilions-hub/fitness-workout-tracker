import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/app_metadata_table.dart';

part 'app_metadata_dao.g.dart';

/// Key/value access over [AppMetadata]. Used for small persisted flags such as
/// the last exercise-catalog sync time.
@DriftAccessor(tables: [AppMetadata])
class AppMetadataDao extends DatabaseAccessor<AppDatabase>
    with _$AppMetadataDaoMixin {
  AppMetadataDao(super.db);

  /// Well-known key: ISO-8601 timestamp of the last successful exercise sync.
  static const String exercisesLastSyncKey = 'exercises_last_sync';

  Future<String?> getValue(String key) async {
    final row = await (select(appMetadata)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value) {
    return into(appMetadata).insertOnConflictUpdate(
      AppMetadataCompanion(key: Value(key), value: Value(value)),
    );
  }
}
