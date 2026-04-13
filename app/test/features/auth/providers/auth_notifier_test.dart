import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:fitness_workout_tracker/core/errors/app_exception.dart';
import 'package:fitness_workout_tracker/core/providers/auth_token_provider.dart';
import 'package:fitness_workout_tracker/core/providers/database_provider.dart';
import 'package:fitness_workout_tracker/features/auth/providers/auth_notifier.dart';
import 'package:fitness_workout_tracker/features/auth/providers/auth_providers.dart';
import 'package:fitness_workout_tracker/features/auth/providers/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAppDatabase extends Mock implements AppDatabase {}

/// A purpose-built fake [UserDao] whose [getUser] blocks until [completer] is
/// completed. Uses [noSuchMethod] for all other [UserDao] methods so the test
/// fails loudly if any unexpected DAO call is made — no Drift lifecycle or
/// mocktail internals involved.
class _BlockingUserDao implements UserDao {
  _BlockingUserDao(this._completer);
  final Completer<UserRow?> _completer;

  @override
  Future<UserRow?> getUser(String id) => _completer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      '${invocation.memberName} is not expected in the race-guard test',
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a fake JWT with the given [sub]. The client never verifies the
/// signature — the server does that on every request.
String _fakeJwt(String sub, {bool isGuest = false}) {
  final payload = base64Url
      .encode(utf8.encode('{"sub":"$sub","isGuest":$isGuest}'))
      .replaceAll('=', '');
  return 'eyJhbGciOiJIUzI1NiJ9.$payload.fakeSignature';
}

/// Creates an in-memory [AppDatabase], seeds it with a single user, and
/// returns it. The caller is responsible for calling [AppDatabase.close].
Future<AppDatabase> _makeSeededDb({
  required String id,
  required String email,
  required String displayName,
  AuthProvider provider = AuthProvider.emailPassword,
  bool isGuest = false,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.userDao.upsertUser(
    UsersCompanion.insert(
      id: id,
      email: email,
      displayName: displayName,
      authProvider: provider,
      isGuest: Value(isGuest),
    ),
  );
  return db;
}

/// Waits until [authProvider] reaches a settled state (neither
/// [AuthInitializing] nor [AuthLoading]) and returns it.
Future<AuthState> _waitForSettled(ProviderContainer container) async {
  final completer = Completer<AuthState>();
  final sub = container.listen<AuthState>(
    authProvider,
    (_, state) {
      if (state is! AuthInitializing && state is! AuthLoading) {
        if (!completer.isCompleted) completer.complete(state);
      }
    },
    fireImmediately: true,
  );
  final result = await completer.future;
  sub.close();
  return result;
}

// ---------------------------------------------------------------------------
// Shared test data
// ---------------------------------------------------------------------------

const _testUser = AuthUser(
  id: 'user-123',
  email: 'alice@test.com',
  displayName: 'Alice',
  isGuest: false,
);

const _guestUser = AuthUser(
  id: 'guest-456',
  email: null,
  displayName: 'Guest',
  isGuest: true,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    registerFallbackValue(const AuthToken(accessToken: 'fallback'));
  });

  // -------------------------------------------------------------------------
  // 1. Initial state — no token
  // -------------------------------------------------------------------------
  group('initial state — no token in storage', () {
    test('resolves to unauthenticated', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await _waitForSettled(container), const AuthState.unauthenticated());
    });
  });

  // -------------------------------------------------------------------------
  // 2. Session restore — token in storage, user in DB
  // -------------------------------------------------------------------------
  group('session restore', () {
    test('restores authenticated state for a full account', () async {
      final db = await _makeSeededDb(
        id: 'user-123',
        email: 'alice@test.com',
        displayName: 'Alice',
      );
      addTearDown(db.close);

      FlutterSecureStorage.setMockInitialValues({
        'access_token': _fakeJwt('user-123'),
        'refresh_token': 'r-tok',
      });

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((_) => db)],
      );
      addTearDown(container.dispose);

      expect(
        await _waitForSettled(container),
        const AuthState.authenticated(user: _testUser),
      );
    });

    test('restores guest state for a guest account', () async {
      final db = await _makeSeededDb(
        id: 'guest-456',
        email: 'guest:guest-456',
        displayName: 'Guest',
        provider: AuthProvider.guest,
        isGuest: true,
      );
      addTearDown(db.close);

      FlutterSecureStorage.setMockInitialValues({
        'access_token': _fakeJwt('guest-456', isGuest: true),
        'refresh_token': 'r-tok',
      });

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((_) => db)],
      );
      addTearDown(container.dispose);

      expect(
        await _waitForSettled(container),
        const AuthState.guest(user: _guestUser),
      );
    });

    test('resolves to unauthenticated when user is not in DB', () async {
      // Empty in-memory DB — simulates a cleared local DB after reinstall.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      FlutterSecureStorage.setMockInitialValues({
        'access_token': _fakeJwt('unknown-user'),
      });

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((_) => db)],
      );
      addTearDown(container.dispose);

      expect(
        await _waitForSettled(container),
        const AuthState.unauthenticated(),
      );
    });

    test('resolves to unauthenticated when JWT is malformed', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'not.a.valid.jwt',
      });

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((_) => db)],
      );
      addTearDown(container.dispose);

      expect(
        await _waitForSettled(container),
        const AuthState.unauthenticated(),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3. Action methods — no token in storage so _restoreSession is not triggered
  // -------------------------------------------------------------------------
  group('action methods', () {
    late _MockAuthRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = _MockAuthRepository();
      container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWith((_) => mockRepo)],
      );
    });

    tearDown(() => container.dispose());

    test('login() → authenticated on success', () async {
      when(() => mockRepo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => _testUser);

      await _waitForSettled(container);
      await container.read(authProvider.notifier).login(
            email: 'alice@test.com',
            password: 'secret',
          );

      expect(
        container.read(authProvider),
        const AuthState.authenticated(user: _testUser),
      );
    });

    test('login() → unauthenticated and rethrows on failure', () async {
      when(() => mockRepo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(const AppException.unauthorized());

      await _waitForSettled(container);

      await expectLater(
        () => container.read(authProvider.notifier).login(
              email: 'alice@test.com',
              password: 'wrong',
            ),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(container.read(authProvider), const AuthState.unauthenticated());
    });

    test('login() → restores previous state on CancelledException', () async {
      when(() => mockRepo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(const AppException.cancelled());

      final priorState = await _waitForSettled(container);

      await expectLater(
        () => container.read(authProvider.notifier).login(
              email: 'alice@test.com',
              password: 'pass',
            ),
        throwsA(isA<CancelledException>()),
      );
      expect(container.read(authProvider), priorState);
    });

    test('register() → authenticated on success', () async {
      when(() => mockRepo.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
          )).thenAnswer((_) async => _testUser);

      await _waitForSettled(container);
      await container.read(authProvider.notifier).register(
            email: 'alice@test.com',
            password: 'secret',
            displayName: 'Alice',
          );

      expect(
        container.read(authProvider),
        const AuthState.authenticated(user: _testUser),
      );
    });

    test('signInAsGuest() → guest on success', () async {
      when(() => mockRepo.signInAsGuest()).thenAnswer((_) async => _guestUser);

      await _waitForSettled(container);
      await container.read(authProvider.notifier).signInAsGuest();

      expect(
        container.read(authProvider),
        const AuthState.guest(user: _guestUser),
      );
    });

    test('logout() → unauthenticated immediately; repository logout called',
        () async {
      when(() => mockRepo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => _testUser);
      when(() => mockRepo.logout()).thenAnswer((_) async {});

      await _waitForSettled(container);
      await container.read(authProvider.notifier).login(
            email: 'alice@test.com',
            password: 'secret',
          );
      await container.read(authProvider.notifier).logout();

      expect(container.read(authProvider), const AuthState.unauthenticated());
      verify(() => mockRepo.logout()).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Generation race guard
  // -------------------------------------------------------------------------
  group('generation race guard', () {
    test('login() state is not overwritten by a lagging _restoreSession()',
        () async {
      // Set a token so build() triggers _restoreSession().
      FlutterSecureStorage.setMockInitialValues({
        'access_token': _fakeJwt('user-123'),
        'refresh_token': 'r-tok',
      });

      final dbReadCompleter = Completer<UserRow?>();

      // _BlockingUserDao stalls getUser() until dbReadCompleter is released.
      // It implements UserDao directly — no mocktail, no Drift lifecycle.
      final blockingDao = _BlockingUserDao(dbReadCompleter);

      // Mock AppDatabase that returns the blocking DAO.
      final mockDb = _MockAppDatabase();
      when(() => mockDb.userDao).thenReturn(blockingDao);

      final mockRepo = _MockAuthRepository();
      when(() => mockRepo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => _testUser);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((_) => mockRepo),
          appDatabaseProvider.overrideWith((_) => mockDb),
        ],
      );
      addTearDown(container.dispose);

      // Step 1: Wait for authTokenProvider to resolve and build() to re-run,
      // which transitions authProvider from initializing → loading and starts
      // _restoreSession. Without this wait, authTokenProvider might resolve
      // AFTER login() completes, causing build() to re-run and overwrite the
      // authenticated state back to loading.
      final loadingReached = Completer<void>();
      final loadSub = container.listen<AuthState>(
        authProvider,
        (_, state) {
          if (state is AuthLoading && !loadingReached.isCompleted) {
            loadingReached.complete();
          }
        },
        fireImmediately: false,
      );
      await loadingReached.future;
      loadSub.close();

      // Step 2: Give _restoreSession one event-loop tick to run past its own
      // `await Future.delayed(Duration.zero)` and block on mockUserDao.getUser().
      await Future<void>.delayed(Duration.zero);

      // Step 3: login() completes and bumps the generation counter, which
      // invalidates the in-flight _restoreSession's future state write.
      await container.read(authProvider.notifier).login(
            email: 'alice@test.com',
            password: 'secret',
          );

      // State is authenticated (from login).
      expect(
        container.read(authProvider),
        const AuthState.authenticated(user: _testUser),
      );

      // Step 4: Release the stalled DB read. _restoreSession completes, but
      // the generation guard (gen < _generation) discards the state write.
      dbReadCompleter.complete(null);
      await Future<void>.delayed(Duration.zero);

      // State must still be the one set by login().
      expect(
        container.read(authProvider),
        const AuthState.authenticated(user: _testUser),
      );
    });
  });
}
