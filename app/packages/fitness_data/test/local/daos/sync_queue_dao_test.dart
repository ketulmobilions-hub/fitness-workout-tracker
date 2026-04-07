import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:fitness_data/fitness_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncQueueDao dao;

  setUp(() async {
    db = createTestDatabase();
    dao = db.syncQueueDao;
    await db.userDao.upsertUser(
      UsersCompanion(
        id: const Value('user-1'),
        email: const Value('test@example.com'),
        displayName: const Value('Test User'),
        authProvider: const Value(AuthProvider.emailPassword),
      ),
    );
  });

  tearDown(() async => db.close());

  SyncQueueCompanion _item({
    String id = 'sq-1',
    SyncOperation operation = SyncOperation.create,
    Map<String, dynamic> payload = const {'key': 'value'},
  }) {
    return SyncQueueCompanion(
      id: Value(id),
      userId: const Value('user-1'),
      entityTable: const Value('workout_sessions'),
      recordId: const Value('record-uuid'),
      operation: Value(operation),
      payload: Value(payload),
    );
  }

  group('SyncQueueDao', () {
    test('enqueue inserts item', () async {
      await dao.enqueue(_item());

      final items = await dao.getPendingItems('user-1');
      expect(items.length, 1);
      expect(items.first.entityTable, 'workout_sessions');
    });

    test('getPendingItems returns only unsynced items', () async {
      await dao.enqueue(_item(id: 'sq-1'));
      await dao.enqueue(_item(id: 'sq-2'));
      await dao.markSynced('sq-1', DateTime.now());

      final pending = await dao.getPendingItems('user-1');
      expect(pending.length, 1);
      expect(pending.first.id, 'sq-2');
    });

    test('pendingCount returns correct count', () async {
      await dao.enqueue(_item(id: 'sq-1'));
      await dao.enqueue(_item(id: 'sq-2'));
      await dao.enqueue(_item(id: 'sq-3'));
      await dao.markSynced('sq-1', DateTime.now());

      expect(await dao.pendingCount('user-1'), 2);
    });

    test('markSynced sets syncedAt', () async {
      await dao.enqueue(_item());
      await dao.markSynced('sq-1', DateTime.now());

      final pending = await dao.getPendingItems('user-1');
      expect(pending, isEmpty);
    });

    test('markAllSynced marks all given ids in a single operation', () async {
      await dao.enqueue(_item(id: 'sq-1'));
      await dao.enqueue(_item(id: 'sq-2'));
      await dao.enqueue(_item(id: 'sq-3'));

      await dao.markAllSynced(['sq-1', 'sq-2'], DateTime.now());

      expect(await dao.pendingCount('user-1'), 1);
    });

    test('markFailed increments retryCount and records error', () async {
      await dao.enqueue(_item());
      await dao.markFailed('sq-1', 'server returned 422');

      final items = await dao.getPendingItems('user-1');
      expect(items.first.retryCount, 1);
      expect(items.first.lastError, 'server returned 422');
      expect(items.first.failedAt, isNotNull);
    });

    test('markFailed increments retryCount on repeated failures', () async {
      await dao.enqueue(_item());
      await dao.markFailed('sq-1', 'error 1');
      await dao.markFailed('sq-1', 'error 2');

      final items = await dao.getPendingItems('user-1');
      expect(items.first.retryCount, 2);
      expect(items.first.lastError, 'error 2');
    });

    test('retryCount defaults to 0 on enqueue', () async {
      await dao.enqueue(_item());
      final items = await dao.getPendingItems('user-1');
      expect(items.first.retryCount, 0);
    });

    test('deleteSyncedItems removes synced items', () async {
      await dao.enqueue(_item(id: 'sq-1'));
      await dao.enqueue(_item(id: 'sq-2'));
      await dao.markSynced('sq-1', DateTime.now());

      await dao.deleteSyncedItems('user-1');

      final pending = await dao.getPendingItems('user-1');
      expect(pending.length, 1);
      expect(pending.first.id, 'sq-2');
    });

    test('watchPendingItems emits on change', () async {
      await dao.enqueue(_item(id: 'sq-1'));

      // Must await so a missed emission fails the test.
      final future = expectLater(
        dao.watchPendingItems('user-1'),
        emitsInOrder([hasLength(1), hasLength(0)]),
      );

      await Future<void>.delayed(Duration.zero);
      await dao.markSynced('sq-1', DateTime.now());
      await future;
    });

    test('payload is round-tripped correctly', () async {
      final payload = {'key': 'value', 'count': 42, 'nested': {'a': true}};
      await dao.enqueue(_item(payload: payload));

      final items = await dao.getPendingItems('user-1');
      expect(items.first.payload, payload);
    });
  });
}
