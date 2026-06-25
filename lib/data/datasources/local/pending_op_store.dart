import '../../../domain/entities/memo.dart';

// @MX:NOTE: [AUTO] PendingOpDart — in-memory representation of a queued offline op.
// Sealed so the SyncService switch is exhaustive and type-safe.
sealed class PendingOpEntry {}

final class PendingSaveOp extends PendingOpEntry {
  PendingSaveOp(this.memo);
  final Memo memo;
}

final class PendingDeleteOp extends PendingOpEntry {
  PendingDeleteOp(this.id);
  final String id;
}

// @MX:ANCHOR: [AUTO] PendingOpStore — durable queue persistence boundary
// @MX:REASON: Injected into SyncService; implemented by HivePendingOpStore and
//             FakePendingOpStore; fan_in >= 2 callers (SyncService + tests).
/// Abstraction for persisting the offline operation queue across app restarts.
///
/// Implementations must be FIFO-preserving: [loadAll] returns ops in the
/// same order they were [append]ed.
abstract interface class PendingOpStore {
  /// Returns all persisted pending ops in insertion (FIFO) order.
  Future<List<PendingOpEntry>> loadAll();

  /// Appends a single op to the persistent store.
  Future<void> append(PendingOpEntry op);

  /// Replaces the entire store contents with [ops].
  ///
  /// Passing an empty list clears the store.
  Future<void> replaceAll(List<PendingOpEntry> ops);
}

// @MX:NOTE: [AUTO] InMemoryPendingOpStore — test double for PendingOpStore.
// Not for production use; allows unit tests to verify persistence behaviour
// without a real Hive runtime.
/// In-memory [PendingOpStore] implementation for unit tests.
class InMemoryPendingOpStore implements PendingOpStore {
  final List<PendingOpEntry> _entries = [];

  @override
  Future<List<PendingOpEntry>> loadAll() async => List.from(_entries);

  @override
  Future<void> append(PendingOpEntry op) async => _entries.add(op);

  @override
  Future<void> replaceAll(List<PendingOpEntry> ops) async {
    _entries
      ..clear()
      ..addAll(ops);
  }
}
