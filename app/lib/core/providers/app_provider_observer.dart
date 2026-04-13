import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Logs Riverpod provider state changes and failures in debug mode.
///
/// Attach to [ProviderScope.observers] in [main]:
/// ```dart
/// const ProviderScope(
///   observers: [AppProviderObserver()],
///   child: FitnessApp(),
/// )
/// ```
base class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (kDebugMode) {
      debugPrint(
        '[Provider] ${context.provider.name ?? context.provider.runtimeType}: $newValue',
      );
    }
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (kDebugMode) {
      debugPrint(
        '[Provider ERROR] ${context.provider.name ?? context.provider.runtimeType}: $error\n$stackTrace',
      );
    }
  }
}
