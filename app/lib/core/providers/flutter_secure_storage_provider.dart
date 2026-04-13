import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'flutter_secure_storage_provider.g.dart';

/// Provides the [FlutterSecureStorage] instance for the lifetime of the app.
///
/// Exposed as a provider so it can be overridden in tests:
/// ```dart
/// ProviderScope(
///   overrides: [
///     flutterSecureStorageProvider.overrideWithValue(fakeStorage),
///   ],
///   child: const MyApp(),
/// )
/// ```
@Riverpod(keepAlive: true)
FlutterSecureStorage flutterSecureStorage(Ref ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
}
