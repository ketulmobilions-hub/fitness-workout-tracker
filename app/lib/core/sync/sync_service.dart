import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:fitness_data/fitness_data.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../providers/connectivity_provider.dart';
import '../providers/database_provider.dart';
import '../providers/dio_provider.dart';
import '../providers/flutter_secure_storage_provider.dart';
import '../../features/auth/providers/auth_notifier.dart';
import '../../features/auth/providers/auth_state.dart';
import '../../features/workout_plans/providers/workout_plan_providers.dart';
import 'sync_state.dart';

part 'sync_service.g.dart';

const _uuid = Uuid();
const _maxRetries = 5;

// Server accepts at most 100 items per push request. Client sends batches of
// 20 to keep individual payloads small and avoid request timeouts.
const _batchSize = 20;

// ─── Providers ────────────────────────────────────────────────────────────────

@riverpod
SyncApiClient syncApiClient(Ref ref) {
  return SyncApiClient(ref.watch(dioProvider));
}

// How long to wait after connectivity is restored before triggering sync.
// Debounces rapid airplane-mode toggles so only one sync fires per reconnect.
const _connectivityDebounceDuration = Duration(seconds: 2);

// How often to sync while the app is open and connected.
const _periodicSyncInterval = Duration(minutes: 5);

@Riverpod(keepAlive: true)
class SyncNotifier extends _$SyncNotifier with WidgetsBindingObserver {
  // Issue 9: Use a Future instead of a bare bool so that callers can choose to
  // await the ongoing sync, and so that the lock is cleared automatically in
  // the finally block even if the sync body throws synchronously.
  Future<void>? _syncFuture;

  // Debounce timer for connectivity restoration events.
  Timer? _connectivityDebounce;

  // Guards _maybeInitialSync so the auth listener and microtask in build()
  // both share a single storage read rather than racing past the async gap.
  Future<void>? _initialSyncCheckFuture;

  @override
  SyncState build() {
    // Issue 3: cancel any debounce timer carried over from a prior build()
    // invocation (e.g., hot-reload or provider invalidation) before setting up
    // fresh state. Without this a stale timer could fire triggerSync() against
    // a partially-initialized notifier.
    _connectivityDebounce?.cancel();
    _connectivityDebounce = null;

    // Register as a WidgetsBindingObserver so didChangeAppLifecycleState fires
    // when the app is brought back to the foreground (AppLifecycleState.resumed).
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _connectivityDebounce?.cancel();
    });

    // Watch connectivity: trigger a flush whenever the device goes from offline
    // to online. Debounced so rapid airplane-mode toggles only fire one sync.
    ref.listen<bool>(
      isConnectedProvider,
      (previous, current) {
        if (current && previous == false) {
          _connectivityDebounce?.cancel();
          _connectivityDebounce = Timer(_connectivityDebounceDuration, triggerSync);
        }
      },
    );

    // Watch auth state: trigger initial sync on first login.
    // Guest accounts cannot access the sync endpoints (requireFullAccount).
    ref.listen<AuthState>(
      authProvider,
      (previous, current) {
        if (current is Authenticated && previous is! Authenticated) {
          _maybeInitialSync(current.user.id);
        }
      },
    );

    // Also handle the case where the provider is initialized AFTER the user
    // is already authenticated (e.g., app restart with saved session).
    Future.microtask(() {
      final authState = ref.read(authProvider);
      if (authState is Authenticated) {
        _maybeInitialSync(authState.user.id);
      }
    });

    // Periodic sync while the app is open: fires every 5 minutes if connected.
    final periodicTimer = Timer.periodic(_periodicSyncInterval, (_) {
      if (ref.read(isConnectedProvider)) triggerSync();
    });
    ref.onDispose(periodicTimer.cancel);

    return const SyncState.synced();
  }

  // ── WidgetsBindingObserver ───────────────────────────────────────────────────

  /// Called by the framework when the app lifecycle state changes.
  /// Trigger a sync whenever the user brings the app back to the foreground,
  /// but only if connected — avoids setting error state in airplane mode.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(isConnectedProvider)) {
      triggerSync();
    }
  }

  /// Checks if this user has ever synced. If not, runs a full pull.
  ///
  /// Coalesces concurrent callers (auth listener + microtask in build) onto a
  /// single shared Future so the storage.read only happens once, closing the
  /// TOCTOU gap where both callers could pass the _syncFuture null-check
  /// synchronously and then both proceed to await storage.read independently.
  Future<void> _maybeInitialSync(String userId) {
    _initialSyncCheckFuture ??= _doMaybeInitialSync(userId);
    return _initialSyncCheckFuture!;
  }

  Future<void> _doMaybeInitialSync(String userId) async {
    try {
      if (_syncFuture != null) return;
      final storage = ref.read(flutterSecureStorageProvider);
      final sinceKey = 'last_synced_at_$userId';
      final existing = await storage.read(key: sinceKey);
      if (existing == null) {
        await performInitialSync();
      }
    } finally {
      _initialSyncCheckFuture = null;
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Flush pending sync items and pull server changes.
  ///
  /// Returns immediately (no-op) for guest and unauthenticated users — the
  /// sync endpoint requires a full account. If a sync is already in flight,
  /// returns the existing Future so callers (e.g. RefreshIndicator) wait for
  /// the ongoing sync to complete rather than seeing an instant no-op.
  Future<void> triggerSync() async {
    // Issue 1: guests have a non-null stableUserId but the sync endpoint
    // requires requireFullAccount — block them before hitting the network.
    final authState = ref.read(authProvider);
    if (authState is! Authenticated) return;

    final userId = ref.read(stableUserIdProvider);
    if (userId == null) return;

    // Issue 6: join in-flight sync instead of returning a completed no-op.
    // This makes RefreshIndicator wait for the actual sync to finish.
    if (_syncFuture != null) return _syncFuture!;

    _syncFuture = _flushQueue(userId);
    try {
      await _syncFuture;
    } finally {
      _syncFuture = null;
    }
  }

  /// Pull all server data for the user (initial sync on first login).
  /// Skips the push phase — there are no local queued changes yet.
  Future<void> performInitialSync() async {
    final userId = ref.read(stableUserIdProvider);
    if (userId == null || _syncFuture != null) return;
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);
    _syncFuture = _runInitialSync(userId);
    try {
      await _syncFuture;
    } finally {
      _syncFuture = null;
    }
  }

  Future<void> _runInitialSync(String userId) async {
    try {
      await _pullServerChanges(userId);
      state = state.copyWith(
        status: SyncStatus.synced,
        pendingCount: 0,
        clearError: true,
      );
    } catch (e) {
      debugPrint('SyncService: initial sync failed: $e');
      state = state.copyWith(
        status: SyncStatus.error,
        lastError: e.toString(),
      );
    }
  }

  // ── Private: flush + pull ───────────────────────────────────────────────────

  Future<void> _flushQueue(String userId) async {
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);

    try {
      final db = ref.read(appDatabaseProvider);
      final items = await db.syncQueueDao.getPendingItems(userId);

      // Filter: skip permanently-failed items and those still in backoff window.
      final now = DateTime.now();
      final eligible = items.where((item) {
        if (item.retryCount >= _maxRetries) return false;
        if (item.failedAt != null && item.retryCount > 0) {
          final backoffSeconds =
              math.min(math.pow(2, item.retryCount).toInt() * 30, 1800);
          final retryAfter =
              item.failedAt!.add(Duration(seconds: backoffSeconds));
          if (now.isBefore(retryAfter)) return false;
        }
        return true;
      }).toList();

      if (eligible.isNotEmpty) {
        await _pushItems(eligible, db.syncQueueDao);
      }

      // After push, pull the latest server changes.
      await _pullServerChanges(userId);

      // Re-count pending items (some may be permanently beyond max retries).
      final remaining = await db.syncQueueDao.pendingCount(userId);
      state = state.copyWith(
        status: remaining > 0 ? SyncStatus.pending : SyncStatus.synced,
        pendingCount: remaining,
        clearError: true,
      );
    } catch (e) {
      debugPrint('SyncService: sync failed: $e');
      state = state.copyWith(
        status: SyncStatus.error,
        lastError: e.toString(),
      );
    }
  }

  Future<void> _pushItems(
    List<SyncQueueRow> items,
    SyncQueueDao dao,
  ) async {
    final client = ref.read(syncApiClientProvider);

    for (var i = 0; i < items.length; i += _batchSize) {
      final batch = items.sublist(
        i,
        math.min(i + _batchSize, items.length),
      );

      final pushItems = batch.map((row) {
        return SyncPushItemDto(
          id: row.id,
          entityTable: row.entityTable,
          recordId: row.recordId,
          operation: row.operation.name, // 'create' | 'update' | 'delete'
          payload: row.payload,
        );
      }).toList();

      final envelope = await client.pushChanges(
        SyncPushRequestDto(items: pushItems),
      );

      final syncedAt = DateTime.now();
      for (final result in envelope.data.results) {
        if (result.status == 'ok') {
          await dao.markSynced(result.id, syncedAt);
        } else {
          await dao.markFailed(result.id, result.error ?? 'unknown error');
          debugPrint(
              'SyncService: item ${result.id} failed: ${result.error}');
        }
      }
    }
  }

  Future<void> _pullServerChanges(String userId) async {
    final storage = ref.read(flutterSecureStorageProvider);
    final sinceKey = 'last_synced_at_$userId';
    final sinceRaw = await storage.read(key: sinceKey);

    final client = ref.read(syncApiClientProvider);
    final envelope = await client.pullChanges(since: sinceRaw);
    final data = envelope.data;

    final db = ref.read(appDatabaseProvider);
    // Issue 15: wrap all upserts in a single Drift transaction so a partial
    // failure leaves the local DB in a consistent state — no half-applied pull.
    await _upsertPullData(db, userId, data);

    // Issue 16: storage.write failure is non-fatal — the pull data is already
    // applied to Drift. The next sync will re-fetch from the previous timestamp
    // (or do a full sync) but will not lose data — Drift upserts are idempotent.
    try {
      await storage.write(key: sinceKey, value: data.syncedAt);
    } catch (e) {
      debugPrint(
          'SyncService: failed to persist last_synced_at — next sync will re-fetch: $e');
    }

    state = state.copyWith(
      lastSyncedAt: DateTime.tryParse(data.syncedAt),
    );
  }

  Future<void> _upsertPullData(
    AppDatabase db,
    String userId,
    SyncPullDataDto data,
  ) async {
    // Issue 15: single Drift transaction — all-or-nothing. If any upsert
    // fails, Drift rolls back the entire batch so the next pull restarts clean.
    await db.transaction(() async {
      // Sessions
      for (final s in data.sessions) {
        await db.workoutSessionDao.upsertSession(WorkoutSessionsCompanion(
          id: Value(s.id),
          userId: Value(userId),
          planId: Value(s.planId),
          planDayId: Value(s.planDayId),
          startedAt: Value(DateTime.parse(s.startedAt)),
          completedAt: Value(s.completedAt != null
              ? DateTime.parse(s.completedAt!)
              : null),
          durationSec: Value(s.durationSec),
          notes: Value(s.notes),
          status: Value(const SessionStatusConverter().fromSql(s.status)),
          createdAt: Value(DateTime.parse(s.createdAt)),
          updatedAt: Value(DateTime.parse(s.updatedAt)),
        ));
      }

      // Exercise logs
      for (final l in data.exerciseLogs) {
        await db.workoutSessionDao.upsertExerciseLog(ExerciseLogsCompanion(
          id: Value(l.id),
          sessionId: Value(l.sessionId),
          exerciseId: Value(l.exerciseId),
          sortOrder: Value(l.sortOrder),
          notes: Value(l.notes),
        ));
      }

      // Set logs
      for (final s in data.setLogs) {
        await db.workoutSessionDao.upsertSetLog(SetLogsCompanion(
          id: Value(s.id),
          exerciseLogId: Value(s.exerciseLogId),
          setNumber: Value(s.setNumber),
          reps: Value(s.reps),
          weightKg: Value(s.weightKg),
          durationSec: Value(s.durationSec),
          distanceM: Value(s.distanceM),
          paceSecPerKm: Value(s.paceSecPerKm),
          heartRate: Value(s.heartRate),
          rpe: Value(s.rpe),
          tempo: Value(s.tempo),
          isWarmup: Value(s.isWarmup),
          completedAt: Value(s.completedAt != null
              ? DateTime.parse(s.completedAt!)
              : null),
        ));
      }

      // Plans
      for (final p in data.plans) {
        await db.workoutPlanDao.upsertPlan(WorkoutPlansCompanion(
          id: Value(p.id),
          userId: Value(userId),
          name: Value(p.name),
          description: Value(p.description),
          isActive: Value(p.isActive),
          scheduleType: Value(
            const ScheduleTypeConverter().fromSql(p.scheduleType),
          ),
          weeksCount: Value(p.weeksCount),
          createdAt: Value(DateTime.parse(p.createdAt)),
          updatedAt: Value(DateTime.parse(p.updatedAt)),
        ));
      }

      // Plan days — weekNumber is non-nullable in Drift (0 = sentinel for "none")
      for (final d in data.planDays) {
        await db.workoutPlanDao.upsertPlanDay(PlanDaysCompanion(
          id: Value(d.id),
          planId: Value(d.planId),
          dayOfWeek: Value(d.dayOfWeek),
          weekNumber: Value(d.weekNumber ?? 0),
          name: Value(d.name),
          sortOrder: Value(d.sortOrder),
          createdAt: Value(DateTime.parse(d.createdAt)),
          updatedAt: Value(DateTime.parse(d.updatedAt)),
        ));
      }

      // Plan day exercises
      for (final e in data.planDayExercises) {
        await db.workoutPlanDao.upsertPlanDayExercise(PlanDayExercisesCompanion(
          id: Value(e.id),
          planDayId: Value(e.planDayId),
          exerciseId: Value(e.exerciseId),
          sortOrder: Value(e.sortOrder),
          targetSets: Value(e.targetSets),
          targetReps: Value(e.targetReps),
          targetDurationSec: Value(e.targetDurationSec),
          targetDistanceM: Value(e.targetDistanceM),
          notes: Value(e.notes),
          createdAt: Value(DateTime.parse(e.createdAt)),
          updatedAt: Value(DateTime.parse(e.updatedAt)),
        ));
      }
    });
  }
}

// ─── Convenience: enqueue a sync item ────────────────────────────────────────

/// Convenience function called by repositories when a server write fails.
/// Queues the change in [dao] for the sync engine to retry later.
Future<void> enqueueSyncItem({
  required SyncQueueDao dao,
  required String userId,
  required String entityTable,
  required String recordId,
  required SyncOperation operation,
  required Map<String, dynamic> payload,
}) async {
  await dao.enqueue(SyncQueueCompanion(
    id: Value(_uuid.v4()),
    userId: Value(userId),
    entityTable: Value(entityTable),
    recordId: Value(recordId),
    operation: Value(operation),
    payload: Value(payload),
    createdAt: Value(DateTime.now()),
  ));
}
