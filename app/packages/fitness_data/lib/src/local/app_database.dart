import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:fitness_domain/fitness_domain.dart';

import 'converters/auth_provider_converter.dart';
import 'converters/date_string_converter.dart';
import 'converters/exercise_type_converter.dart';
import 'converters/json_string_converter.dart';
import 'converters/record_type_converter.dart';
import 'converters/schedule_type_converter.dart';
import 'converters/session_status_converter.dart';
import 'converters/streak_day_status_converter.dart';
import 'converters/sync_operation_converter.dart';
import 'daos/exercise_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/user_dao.dart';
import 'daos/workout_plan_dao.dart';
import 'daos/workout_session_dao.dart';
import 'tables/exercise_library_tables.dart';
import 'tables/progress_tables.dart';
import 'tables/sync_queue_table.dart';
import 'tables/users_table.dart';
import 'tables/workout_plan_tables.dart';
import 'tables/workout_session_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    MuscleGroups,
    Exercises,
    ExerciseMuscleGroups,
    WorkoutPlans,
    PlanDays,
    PlanDayExercises,
    WorkoutSessions,
    ExerciseLogs,
    SetLogs,
    PersonalRecords,
    Streaks,
    StreakHistory,
    SyncQueue,
  ],
  daos: [
    UserDao,
    ExerciseDao,
    WorkoutPlanDao,
    WorkoutSessionDao,
    ProgressDao,
    SyncQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Production constructor — opens the on-device SQLite file via drift_flutter.
  ///
  /// Pass a custom [QueryExecutor] to inject a different backend (e.g.
  /// [NativeDatabase.memory()] in tests). For app-level widget tests you can
  /// also override the Riverpod provider:
  /// ```dart
  /// ProviderScope(
  ///   overrides: [
  ///     appDatabaseProvider.overrideWith(
  ///       (ref) => AppDatabase(NativeDatabase.memory()),
  ///     ),
  ///   ],
  /// )
  /// ```
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        // SQLite does not enforce foreign-key constraints by default.
        // This pragma enables ON DELETE / ON UPDATE cascade checks for every
        // connection that opens this database.
        await customStatement('PRAGMA foreign_keys = ON');
      },
      onCreate: (Migrator m) async {
        await m.createAll();
        // Indexes for the two most-scanned hot paths.
        // workout_sessions(user_id, started_at): drives watchSessionsForUser
        await customStatement(
          'CREATE INDEX idx_sessions_user_started '
          'ON workout_sessions (user_id, started_at DESC)',
        );
        // sync_queue(user_id, synced_at): drives getPendingItems
        await customStatement(
          'CREATE INDEX idx_sync_queue_user_synced '
          'ON sync_queue (user_id, synced_at)',
        );
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // v1 → v2: add createdAt/updatedAt to plan_days and plan_day_exercises
        // to support last-write-wins conflict resolution in the sync engine.
        // Existing rows receive the wall-clock time at migration (SQLite sets
        // the column to its DEFAULT expression for all pre-existing rows).
        // This means pre-migration rows appear "created/updated now" rather
        // than at their true server timestamps — acceptable for dev data.
        if (from < 2) {
          await m.addColumn(planDays, planDays.createdAt);
          await m.addColumn(planDays, planDays.updatedAt);
          await m.addColumn(planDayExercises, planDayExercises.createdAt);
          await m.addColumn(planDayExercises, planDayExercises.updatedAt);
        }
      },
    );
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'fitness_tracker');
}
