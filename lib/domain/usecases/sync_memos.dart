import '../repositories/memo_repository.dart';
import '../../data/datasources/remote/memo_remote_datasource.dart';

// @MX:ANCHOR: [AUTO] SyncStore — lastSyncedAt persistence boundary
// @MX:REASON: SyncMemos reads and writes this to enable incremental sync;
// fan_in >= 2 (SyncMemos + syncServiceProvider); testable via mock.
/// Abstraction for persisting the last-synced timestamp across app restarts.
abstract interface class SyncStore {
  /// Returns the stored last-synced timestamp, or null if never synced.
  Future<DateTime?> readLastSyncedAt();

  /// Persists [timestamp] as the last-synced timestamp.
  Future<void> writeLastSyncedAt(DateTime timestamp);
}

/// Synchronize local memos with the remote server using Last-Write-Wins (LWW).
///
/// Algorithm:
/// 1. Fetch remote changes since last sync (or all if first sync).
/// 2. For each remote memo:
///    - If deleted_at != null → delete locally (if present).
///    - Else if not in local → create locally.
///    - Else if remote is newer (LWW) → update locally.
/// 3. Persist lastSyncedAt via [SyncStore] for incremental future syncs.
///
/// REQ-B-004: LWW conflict resolution.
/// REQ-B-005: Incremental sync via getSince().
/// REQ-B-006: Soft-delete propagation from server to local.
class SyncMemos {
  SyncMemos({
    required MemoRepository localRepo,
    required MemoRemoteDataSource remoteDatasource,
    required SyncStore syncStore,
    DateTime? lastSyncedAt,
  })  : _localRepo = localRepo,
        _remoteDatasource = remoteDatasource,
        _syncStore = syncStore,
        _lastSyncedAt = lastSyncedAt;

  final MemoRepository _localRepo;
  final MemoRemoteDataSource _remoteDatasource;
  final SyncStore _syncStore;
  DateTime? _lastSyncedAt;

  /// Loads persisted [lastSyncedAt] from [SyncStore].
  ///
  /// Call this once after construction (before [call]) to resume incremental
  /// sync across app restarts. If already set via constructor, this is a no-op.
  Future<void> initialize() async {
    _lastSyncedAt ??= await _syncStore.readLastSyncedAt();
  }

  /// Execute the sync. Returns normally on success, throws on failure.
  Future<void> call() async {
    final since = _lastSyncedAt;
    final remoteModels = since != null
        ? await _remoteDatasource.getSince(since)
        : await _remoteDatasource.getAll();

    final localMemos = await _localRepo.getAll();
    final localById = {for (final m in localMemos) m.id: m};

    for (final remote in remoteModels) {
      if (remote.deletedAt != null) {
        // Remote is soft-deleted → propagate deletion locally if present
        if (localById.containsKey(remote.id)) {
          await _localRepo.delete(remote.id);
        }
        continue;
      }

      final local = localById[remote.id];
      if (local == null) {
        // New memo from server → create locally
        await _localRepo.create(remote.toMemo());
      } else if (remote.updatedAt.isAfter(local.updatedAt)) {
        // Remote is newer → overwrite local (LWW)
        await _localRepo.update(remote.toMemo());
      }
      // else: local is newer or equal → keep local
    }

    final now = DateTime.now().toUtc();
    _lastSyncedAt = now;
    await _syncStore.writeLastSyncedAt(now);
  }
}
