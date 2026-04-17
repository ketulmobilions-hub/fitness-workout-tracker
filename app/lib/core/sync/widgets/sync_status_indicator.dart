import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync_service.dart';
import '../sync_state.dart';

/// Small widget displayed in the app bar (or wherever chosen) to surface
/// the current sync state to the user:
///
///   Synced   → faint green check icon
///   Pending  → orange clock icon with pending-count badge
///   Syncing  → small circular progress indicator
///   Error    → orange warning icon with tooltip
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    return switch (syncState.status) {
      SyncStatus.syncing => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      SyncStatus.pending => Tooltip(
          message: '${syncState.pendingCount} change(s) waiting to sync',
          child: Badge(
            label: Text('${syncState.pendingCount}'),
            child: const Icon(Icons.schedule, color: Colors.orange),
          ),
        ),
      SyncStatus.error => Tooltip(
          message: syncState.lastError ?? 'Sync error',
          child: const Icon(Icons.sync_problem, color: Colors.orange),
        ),
      SyncStatus.synced => const Tooltip(
          message: 'All changes synced',
          child: Icon(Icons.cloud_done, color: Colors.green),
        ),
    };
  }
}
