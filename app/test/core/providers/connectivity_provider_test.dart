import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fitness_workout_tracker/core/providers/connectivity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isConnectedProvider', () {
    /// Creates a container with [connectivityProvider] overridden by [stream].
    ProviderContainer makeContainer(Stream<List<ConnectivityResult>> stream) {
      return ProviderContainer(
        overrides: [
          connectivityProvider.overrideWith((ref) => stream),
        ],
      );
    }

    /// Waits until [connectivityProvider] emits its first non-loading state.
    Future<void> waitForConnectivity(ProviderContainer container) async {
      final completer = Completer<void>();
      final sub = container.listen<AsyncValue<List<ConnectivityResult>>>(
        connectivityProvider,
        (_, next) {
          if (next is! AsyncLoading && !completer.isCompleted) {
            completer.complete();
          }
        },
        fireImmediately: true,
      );
      await completer.future;
      sub.close();
    }

    test('returns true when loading (optimistic default)', () {
      final container = makeContainer(const Stream.empty());
      addTearDown(container.dispose);

      expect(container.read(isConnectedProvider), isTrue);
    });

    test('returns true when wifi connected', () async {
      final container =
          makeContainer(Stream.value([ConnectivityResult.wifi]));
      addTearDown(container.dispose);

      await waitForConnectivity(container);
      expect(container.read(isConnectedProvider), isTrue);
    });

    test('returns false when no connection', () async {
      final container =
          makeContainer(Stream.value([ConnectivityResult.none]));
      addTearDown(container.dispose);

      await waitForConnectivity(container);
      expect(container.read(isConnectedProvider), isFalse);
    });

    test('returns true when mobile connected', () async {
      final container =
          makeContainer(Stream.value([ConnectivityResult.mobile]));
      addTearDown(container.dispose);

      await waitForConnectivity(container);
      expect(container.read(isConnectedProvider), isTrue);
    });

    test('returns false when connectivity stream errors (fail-closed)', () async {
      final container = makeContainer(
        Stream.error(Exception('platform channel error')),
      );
      addTearDown(container.dispose);

      await waitForConnectivity(container);
      expect(container.read(isConnectedProvider), isFalse);
    });
  });
}
