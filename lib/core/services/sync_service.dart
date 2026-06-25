import '../../data/datasources/local/pending_op_store.dart';
import '../../data/datasources/remote/backend_stt_service.dart';
import '../../data/datasources/remote/memo_remote_datasource.dart';
import '../../data/models/memo_model.dart';
import '../../domain/entities/memo.dart';
import '../../domain/usecases/sync_memos.dart';

/// Abstract network connectivity checker (injectable for testing).
abstract interface class NetworkChecker {
  Future<bool> isConnected();
}

// @MX:NOTE: [AUTO] _PendingOp — internal tagged union for in-memory cached ops.
// Mirrors PendingOpEntry from PendingOpStore; used for synchronous pendingQueueLength.
sealed class _PendingOp {}

final class _SaveOp extends _PendingOp {
  _SaveOp(this.memo);
  final Memo memo;
}

final class _DeleteOp extends _PendingOp {
  _DeleteOp(this.id);
  final String id;
}

/// Manages automatic synchronization triggered by app lifecycle and memo saves.
///
/// Gating rules:
/// - All sync methods are no-ops when no access token is present (not logged in).
/// - Network operations require isConnected() == true; else operations are queued.
///
/// Offline operations are persisted to [PendingOpStore] so they survive a
/// force-quit/restart and replay on the next [syncNow] call.
///
/// # @MX:NOTE: [AUTO] SyncService — bidirectional sync coordinator
/// # @MX:WARN: [AUTO] All push/pull errors are swallowed (best-effort)
/// # @MX:REASON: Sync must never break offline-first local CRUD. Network
/// #             errors are logged but not re-thrown to callers.
///
/// REQ-B-009: Triggers sync on foreground + memo save (when online + logged in).
/// REQ-B-010: Queues operations offline and replays on reconnect.
// @MX:ANCHOR: [AUTO] SyncService — central sync coordinator
// @MX:REASON: Called by MemoNotifier (save/delete), HomePage (foreground),
// and auth state listener; fan_in >= 3.
class SyncService {
  SyncService({
    required SyncMemos syncMemos,
    required NetworkChecker networkChecker,
    required MemoRemoteDataSource remoteDataSource,
    required SecureTokenStore tokenStore,
    required PendingOpStore pendingOpStore,
  })  : _syncMemos = syncMemos,
        _networkChecker = networkChecker,
        _remoteDataSource = remoteDataSource,
        _tokenStore = tokenStore,
        _pendingOpStore = pendingOpStore;

  final SyncMemos _syncMemos;
  final NetworkChecker _networkChecker;
  final MemoRemoteDataSource _remoteDataSource;
  final SecureTokenStore _tokenStore;

  // @MX:ANCHOR: [AUTO] _pendingOpStore — durable queue backing store
  // @MX:REASON: Source of truth for queued ops across sessions; fan_in >= 2
  //             (enqueue paths in onMemoSaved/onMemoDeleted and syncNow replay).
  final PendingOpStore _pendingOpStore;

  // @MX:NOTE: [AUTO] _cachedCount mirrors store length for synchronous
  // pendingQueueLength getter. Kept in sync on every enqueue and after syncNow.
  int _cachedCount = 0;

  // @MX:NOTE: [AUTO] In-flight guard: prevents concurrent syncNow() calls from
  // stacking up (e.g., 30-second poll fires during a slow network response).
  bool _isSyncing = false;

  /// Number of operations queued for sync (for testing and UI badge).
  ///
  /// Synchronous. Mirrors the durable store count; updated on every enqueue
  /// and after syncNow drains the queue.
  int get pendingQueueLength => _cachedCount;

  /// Returns true when a JWT access token is present (user is logged in).
  Future<bool> _isLoggedIn() async {
    final token = await _tokenStore.readAccessToken();
    return token != null;
  }

  /// Persists [op] to the durable store and increments the cached count.
  Future<void> _enqueue(_PendingOp op) async {
    final entry = switch (op) {
      _SaveOp(:final memo) => PendingSaveOp(memo),
      _DeleteOp(:final id) => PendingDeleteOp(id),
    };
    await _pendingOpStore.append(entry);
    _cachedCount++;
  }

  /// Called after a memo is saved (create or update) by the user.
  ///
  /// If logged in AND online → PUSH via PUT /memos/{id} (upsert).
  /// If logged in AND offline → enqueue for later replay (persisted).
  /// If not logged in → no-op (local-only mode).
  Future<void> onMemoSaved(Memo memo) async {
    if (!await _isLoggedIn()) return;

    if (await _networkChecker.isConnected()) {
      try {
        await _remoteDataSource.update(MemoModel.fromMemo(memo));
      } catch (_) {
        // Best-effort: persist on failure so the op survives a restart
        await _enqueue(_SaveOp(memo));
      }
    } else {
      await _enqueue(_SaveOp(memo));
    }
  }

  /// Called after a memo is deleted by the user.
  ///
  /// If logged in AND online → PUSH soft-delete via DELETE /memos/{id}.
  /// If logged in AND offline → enqueue for later replay (persisted).
  /// If not logged in → no-op.
  Future<void> onMemoDeleted(String id) async {
    if (!await _isLoggedIn()) return;

    if (await _networkChecker.isConnected()) {
      try {
        await _remoteDataSource.delete(id);
      } catch (_) {
        await _enqueue(_DeleteOp(id));
      }
    } else {
      await _enqueue(_DeleteOp(id));
    }
  }

  /// Called when the app comes to the foreground (REQ-B-009), or explicitly
  /// after login to trigger a full sync cycle.
  ///
  /// Replays the pending queue (FIFO) then performs a pull (SyncMemos.call).
  /// All errors are swallowed — never throws to caller.
  Future<void> onAppForeground() async => syncNow();

  /// Replay queued operations (from durable store) then perform a pull sync.
  ///
  /// No-op when not logged in, not online, or a sync is already in progress.
  /// The in-flight guard ensures the 30-second poll timer never triggers
  /// concurrent backend requests during a slow network response.
  ///
  /// On startup, any ops persisted from a previous session (before force-quit)
  /// are loaded from [_pendingOpStore] and replayed here.
  Future<void> syncNow() async {
    if (_isSyncing) return;
    // Claim the lock synchronously before any await so concurrent callers
    // that arrive while we are awaiting _isLoggedIn() or isConnected() still
    // see _isSyncing == true and return early.
    _isSyncing = true;
    try {
      if (!await _isLoggedIn()) return;
      if (!await _networkChecker.isConnected()) return;
      // Ensure lastSyncedAt is loaded from persistent store before first sync
      await _syncMemos.initialize();

      // Load persisted ops (includes any from previous sessions after restart)
      final entries = await _pendingOpStore.loadAll();

      // Clear the store first (consistent state: ops are now in-memory only)
      await _pendingOpStore.replaceAll([]);
      _cachedCount = 0;

      // Replay in FIFO order
      for (final entry in entries) {
        try {
          switch (entry) {
            case PendingSaveOp(:final memo):
              await _remoteDataSource.update(MemoModel.fromMemo(memo));
            case PendingDeleteOp(:final id):
              await _remoteDataSource.delete(id);
          }
        } catch (_) {
          // Best-effort: if replay fails, the op is dropped (not re-queued).
          // A subsequent full sync will reconcile any remaining divergence.
        }
      }

      // Pull remote changes after pushing local ops
      try {
        await _syncMemos.call();
      } catch (_) {
        // Best-effort pull — never throw to caller
      }
    } finally {
      _isSyncing = false;
    }
  }
}
