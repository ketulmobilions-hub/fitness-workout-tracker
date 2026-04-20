enum SyncStatus { synced, pending, syncing, error }

class SyncState {
  const SyncState({
    required this.status,
    required this.pendingCount,
    this.lastSyncedAt,
    this.lastError,
  });

  const SyncState.synced()
      : status = SyncStatus.synced,
        pendingCount = 0,
        lastSyncedAt = null,
        lastError = null;

  final SyncStatus status;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? lastError;

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearError = false,
    bool clearLastSyncedAt = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: clearLastSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}
