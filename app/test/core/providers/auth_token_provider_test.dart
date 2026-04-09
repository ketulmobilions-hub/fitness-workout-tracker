import 'package:fitness_workout_tracker/core/providers/auth_token_provider.dart';
import 'package:fitness_workout_tracker/core/providers/flutter_secure_storage_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // flutter_secure_storage mock replaces the platform channel with an in-memory
  // store. Reset before each test to ensure isolation.
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AuthTokenNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('build returns null when no tokens in storage', () async {
      final state = await container.read(authTokenProvider.future);
      expect(state, isNull);
    });

    test('build loads tokens from storage', () async {
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'stored-access',
        'refresh_token': 'stored-refresh',
      });
      final freshContainer = ProviderContainer();
      addTearDown(freshContainer.dispose);

      final token = await freshContainer.read(authTokenProvider.future);
      expect(token?.accessToken, 'stored-access');
      expect(token?.refreshToken, 'stored-refresh');
    });

    test('setTokens updates state and persists to storage', () async {
      final notifier = container.read(authTokenProvider.notifier);
      await notifier.setTokens(
        const AuthToken(accessToken: 'new-access', refreshToken: 'new-refresh'),
      );

      final state = container.read(authTokenProvider).value;
      expect(state?.accessToken, 'new-access');
      expect(state?.refreshToken, 'new-refresh');

      // Verify persisted to storage
      final storage = container.read(flutterSecureStorageProvider);
      expect(await storage.read(key: 'access_token'), 'new-access');
      expect(await storage.read(key: 'refresh_token'), 'new-refresh');
    });

    test('clearTokens nulls state and removes from storage', () async {
      final notifier = container.read(authTokenProvider.notifier);
      await notifier.setTokens(
        const AuthToken(accessToken: 'some-token', refreshToken: 'some-refresh'),
      );
      await notifier.clearTokens();

      expect(container.read(authTokenProvider).value, isNull);

      final storage = container.read(flutterSecureStorageProvider);
      expect(await storage.read(key: 'access_token'), isNull);
      expect(await storage.read(key: 'refresh_token'), isNull);
    });

    test('setTokens without refreshToken does not write refresh key to storage',
        () async {
      final notifier = container.read(authTokenProvider.notifier);
      await notifier.setTokens(
        const AuthToken(accessToken: 'access-only'),
      );

      // In-memory state has no refresh token
      expect(container.read(authTokenProvider).value?.refreshToken, isNull);

      // Storage must NOT have the refresh_token key
      final storage = container.read(flutterSecureStorageProvider);
      expect(await storage.read(key: 'refresh_token'), isNull);
    });

    test('setTokens with no refreshToken deletes a previously stored refresh token',
        () async {
      // Arrange: first set tokens with a refresh token
      final notifier = container.read(authTokenProvider.notifier);
      await notifier.setTokens(
        const AuthToken(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        ),
      );

      // Act: update with access-only token (no refresh)
      await notifier.setTokens(
        const AuthToken(accessToken: 'new-access'),
      );

      // Storage must NOT retain the old refresh token
      final storage = container.read(flutterSecureStorageProvider);
      expect(await storage.read(key: 'refresh_token'), isNull);

      // Cold-restart simulation: fresh container re-reads storage
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'new-access',
        // refresh_token intentionally absent
      });
      final freshContainer = ProviderContainer();
      addTearDown(freshContainer.dispose);
      final reloadedToken = await freshContainer.read(authTokenProvider.future);
      expect(reloadedToken?.refreshToken, isNull);
    });
  });
}
