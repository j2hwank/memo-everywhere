import '../../data/datasources/remote/backend_stt_service.dart';
import '../../data/datasources/remote/memo_remote_datasource.dart';
import '../../data/models/memo_model.dart';
import '../../domain/entities/memo.dart';
import '../../domain/usecases/sync_memos.dart';

/// Abstract network connectivity checker (injectable for testing).
abstract interface class NetworkChecker {
  Future<bool> isConnected();
}

// @MX:NOTE: [AUTO] _PendingOp — internal tagged union for queued offline ops.
// Avoids a separate queue per op type while keeping replay logic simple.
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
  })  : _syncMemos = syncMemos,
        _networkChecker = networkChecker,
        _remoteDataSource = remoteDataSource,
        _tokenStore = tokenStore;

  final SyncMemos _syncMemos;
  final NetworkChecker _networkChecker;
  final MemoRemoteDataSource _remoteDataSource;
  final SecureTokenStore _tokenStore;
  final List<_PendingOp> _queue = [];

  // @MX:NOTE: [AUTO] In-flight guard: prevents concurrent syncNow() calls from
  // stacking up (e.g., 30-second poll fires during a slow network response).
  bool _isSyncing = false;

  /// Number of operations queued for sync (for testing and UI badge).
  int get pendingQueueLength => _queue.length;

  /// Returns true when a JWT access token is present (user is logged in).
  Future<bool> _isLoggedIn() async {
    final token = await _tokenStore.readAccessToken();
    return token != null;
  }

  /// Called after a memo is saved (create or update) by the user.
  ///
  /// If logged in AND online → PUSH via PUT /memos/{id} (upsert).
  /// If logged in AND offline → enqueue for later replay.
  /// If not logged in → no-op (local-only mode).
  Future<void> onMemoSaved(Memo memo) async {
    if (!await _isLoggedIn()) return;

    if (await _networkChecker.isConnected()) {
      try {
        await _remoteDataSource.update(MemoModel.fromMemo(memo));
      } catch (_) {
        // Best-effort: enqueue on failure so the op is not lost
        _queue.add(_SaveOp(memo));
      }
    } else {
      _queue.add(_SaveOp(memo));
    }
  }

  /// Called after a memo is deleted by the user.
  ///
  /// If logged in AND online → PUSH soft-delete via DELETE /memos/{id}.
  /// If logged in AND offline → enqueue for later replay.
  /// If not logged in → no-op.
  Future<void> onMemoDeleted(String id) async {
    if (!await _isLoggedIn()) return;

    if (await _networkChecker.isConnected()) {
      try {
        await _remoteDataSource.delete(id);
      } catch (_) {
        _queue.add(_DeleteOp(id));
      }
    } else {
      _queue.add(_DeleteOp(id));
    }
  }

  /// Called when the app comes to the foreground (REQ-B-009), or explicitly
  /// after login to trigger a full sync cycle.
  ///
  /// Replays the pending queue (FIFO) then performs a pull (SyncMemos.call).
  /// All errors are swallowed — never throws to caller.
  Future<void> onAppForeground() async => syncNow();

  /// Replay queued operations then perform a pull sync.
  ///
  /// No-op when not logged in, not online, or a sync is already in progress.
  /// The in-flight guard ensures the 30-second poll timer never triggers
  /// concurrent backend requests during a slow network response.
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

      // Replay queued ops in FIFO order
      final ops = List<_PendingOp>.from(_queue);
      _queue.clear();

      for (final op in ops) {
        try {
          switch (op) {
            case _SaveOp(:final memo):
              await _remoteDataSource.update(MemoModel.fromMemo(memo));
            case _DeleteOp(:final id):
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
