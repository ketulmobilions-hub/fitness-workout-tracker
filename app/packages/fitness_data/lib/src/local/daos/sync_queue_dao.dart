import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_queue_table.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Stream<List<SyncQueueRow>> watchPendingItems(String userId) {
    return (select(syncQueue)
          ..where((t) =>
              t.userId.equals(userId) & t.syncedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<SyncQueueRow>> getPendingItems(String userId) {
    return (select(syncQueue)
          ..where((t) =>
              t.userId.equals(userId) & t.syncedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> enqueue(SyncQueueCompanion companion) {
    return into(syncQueue).insertOnConflictUpdate(companion);
  }

  Future<void> markSynced(String id, DateTime syncedAt) {
    return (update(syncQueue)..where((t) => t.id.equals(id)))
        .write(SyncQueueCompanion(syncedAt: Value(syncedAt)));
  }

  // Single UPDATE … WHERE id IN (…) — avoids N round-trips for large batches.
  Future<void> markAllSynced(List<String> ids, DateTime syncedAt) {
    return (update(syncQueue)..where((t) => t.id.isIn(ids)))
        .write(SyncQueueCompanion(syncedAt: Value(syncedAt)));
  }

  /// Increments [retryCount], records the [error] message, and stamps
  /// [failedAt]. The sync engine uses this to implement exponential backoff
  /// and to skip items that exceed a maximum retry threshold.
  Future<void> markFailed(String id, String error) {
    return transaction(() async {
      final row = await (select(syncQueue)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      await (update(syncQueue)..where((t) => t.id.equals(id))).write(
        SyncQueueCompanion(
          retryCount: Value(row.retryCount + 1),
          lastError: Value(error),
          failedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<int> deleteSyncedItems(String userId) {
    return (delete(syncQueue)
          ..where((t) =>
              t.userId.equals(userId) & t.syncedAt.isNotNull()))
        .go();
  }

  Future<int> pendingCount(String userId) async {
    final count = countAll(
      filter: syncQueue.userId.equals(userId) & syncQueue.syncedAt.isNull(),
    );
    final query = selectOnly(syncQueue)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
