import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:fitness_data/fitness_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late UserDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = db.userDao;
  });

  tearDown(() async => db.close());

  UsersCompanion _user({
    String id = 'user-1',
    String email = 'test@example.com',
    String displayName = 'Test User',
    AuthProvider authProvider = AuthProvider.emailPassword,
  }) {
    return UsersCompanion(
      id: Value(id),
      email: Value(email),
      displayName: Value(displayName),
      authProvider: Value(authProvider),
    );
  }

  group('UserDao', () {
    test('upsertUser inserts a new user', () async {
      await dao.upsertUser(_user());

      final result = await dao.getUser('user-1');
      expect(result, isNotNull);
      expect(result!.email, 'test@example.com');
    });

    test('upsertUser updates an existing user', () async {
      await dao.upsertUser(_user());
      await dao.upsertUser(
        _user().copyWith(displayName: const Value('Updated Name')),
      );

      final result = await dao.getUser('user-1');
      expect(result!.displayName, 'Updated Name');
    });

    test('upsertUser stamps updatedAt when not provided', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await dao.upsertUser(_user());
      final result = await dao.getUser('user-1');
      expect(result!.updatedAt.isAfter(before), isTrue);
    });

    test('upsertUser preserves explicit updatedAt (sync path)', () async {
      final serverTime = DateTime(2024, 1, 1, 12);
      await dao.upsertUser(
        _user().copyWith(updatedAt: Value(serverTime)),
      );
      final result = await dao.getUser('user-1');
      expect(result!.updatedAt, serverTime);
    });

    test('getUser returns null for unknown id', () async {
      final result = await dao.getUser('nonexistent');
      expect(result, isNull);
    });

    test('userExists returns true after insert', () async {
      await dao.upsertUser(_user());
      expect(await dao.userExists('user-1'), isTrue);
    });

    test('userExists returns false for unknown id', () async {
      expect(await dao.userExists('nonexistent'), isFalse);
    });

    test('deleteUser removes the user', () async {
      await dao.upsertUser(_user());
      await dao.deleteUser('user-1');
      expect(await dao.getUser('user-1'), isNull);
    });

    test('watchUser emits updated value after upsert', () async {
      await dao.upsertUser(_user());

      // Register the expectation first, then trigger the change.
      // Must be awaited so a missed emission fails the test.
      final future = expectLater(
        dao.watchUser('user-1'),
        emitsInOrder([
          isA<UserRow>().having((r) => r.displayName, 'displayName', 'Test User'),
          isA<UserRow>()
              .having((r) => r.displayName, 'displayName', 'New Name'),
        ]),
      );

      await Future<void>.delayed(Duration.zero);
      await dao.upsertUser(
        _user().copyWith(displayName: const Value('New Name')),
      );
      await future;
    });

    test('watchUser emits null after delete', () async {
      await dao.upsertUser(_user());

      final future = expectLater(
        dao.watchUser('user-1'),
        emitsInOrder([isNotNull, isNull]),
      );

      await Future<void>.delayed(Duration.zero);
      await dao.deleteUser('user-1');
      await future;
    });

    test('preferences defaults to empty map', () async {
      await dao.upsertUser(_user());
      final result = await dao.getUser('user-1');
      expect(result!.preferences, <String, dynamic>{});
    });

    test('isGuest defaults to false', () async {
      await dao.upsertUser(_user());
      final result = await dao.getUser('user-1');
      expect(result!.isGuest, isFalse);
    });
  });
}
