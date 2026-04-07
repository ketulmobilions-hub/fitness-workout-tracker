import 'package:fitness_data/fitness_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

/// Provides the singleton [AppDatabase] for the lifetime of the app.
///
/// **keepAlive: true** — the SQLite file handle must live for the full app
/// session. Without this, Riverpod could garbage-collect the provider between
/// navigations, closing and re-opening the database repeatedly.
///
/// **ref.onDispose** — fires only when the [ProviderContainer] is disposed
/// (app exit). In development, hot-restart disposes the container, so you may
/// see sqlite3 "unclosed database" warnings in the debug console — this is
/// expected and harmless.
///
/// **Testing** — inject an in-memory database via a provider override:
/// ```dart
/// ProviderScope(
///   overrides: [
///     appDatabaseProvider.overrideWith(
///       (ref) => AppDatabase(NativeDatabase.memory()),
///     ),
///   ],
///   child: const MyApp(),
/// )
/// ```
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
