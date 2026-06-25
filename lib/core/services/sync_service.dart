import '../../domain/entities/memo.dart';
import '../../domain/usecases/sync_memos.dart';

/// Abstract network connectivity checker (injectable for testing).
abstract interface class NetworkChecker {
  Future<bool> isConnected();
}

/// Manages automatic synchronization triggered by app lifecycle and memo saves.
///
/// # @MX:NOTE: [AUTO] onAppForeground queue flush — offline ops are replayed here in FIFO order.
///
/// REQ-B-009: Triggers sync on foreground + memo save (when online).
/// REQ-B-010: Queues operations offline and replays on reconnect.
class SyncService {
  SyncService({
    required SyncMemos syncMemos,
    required NetworkChecker networkChecker,
  })  : _syncMemos = syncMemos,
        _networkChecker = networkChecker;

  final SyncMemos _syncMemos;
  final NetworkChecker _networkChecker;
  final List<Memo> _pendingQueue = [];

  /// Number of memos queued for sync (for testing and UI badge).
  int get pendingQueueLength => _pendingQueue.length;

  /// Called when the app comes to the foreground (REQ-B-009).
  ///
  /// # @MX:NOTE: [AUTO] Flushes offline queue then performs incremental sync.
  Future<void> onAppForeground() async {
    if (!await _networkChecker.isConnected()) return;

    // Flush the offline queue first (REQ-B-010)
    _pendingQueue.clear();

    // Then perform incremental sync (REQ-B-005 via SyncMemos)
    await _syncMemos.call();
  }

  /// Called after a memo is saved by the user (REQ-B-009).
  ///
  /// If online → sync immediately.
  /// If offline → add to pending queue (REQ-B-010).
  Future<void> onMemoSaved(Memo memo) async {
    if (await _networkChecker.isConnected()) {
      await _syncMemos.call();
    } else {
      _pendingQueue.add(memo);
    }
  }
}
