import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/users_table.dart';

part 'user_dao.g.dart';

@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(super.db);

  Stream<UserRow?> watchUser(String id) {
    return (select(users)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<UserRow?> getUser(String id) {
    return (select(users)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertUser(UsersCompanion companion) {
    // Always stamp updatedAt for local writes so the sync engine's
    // last-write-wins logic picks up local mutations. If the caller
    // explicitly provides updatedAt (e.g. when syncing from server),
    // their value is preserved.
    final toWrite = companion.updatedAt.present
        ? companion
        : companion.copyWith(updatedAt: Value(DateTime.now()));
    return into(users).insertOnConflictUpdate(toWrite);
  }

  Future<int> deleteUser(String id) {
    return (delete(users)..where((t) => t.id.equals(id))).go();
  }

  Future<bool> userExists(String id) async {
    final row = await getUser(id);
    return row != null;
  }
}
