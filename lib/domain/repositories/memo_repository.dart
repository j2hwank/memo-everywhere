import '../entities/memo.dart';

// @MX:ANCHOR fan_in=4 — all UseCases depend on this interface.
// @MX:REASON: Every CRUD usecase calls exactly one method here; any signature
//             change propagates to all four callers simultaneously.
abstract interface class MemoRepository {
  /// Returns all persisted memos, sorted by [Memo.updatedAt] descending.
  Future<List<Memo>> getAll();

  /// Persists [memo] and returns the stored entity.
  Future<void> create(Memo memo);

  /// Replaces the stored entry for [memo.id] with the provided values.
  Future<void> update(Memo memo);

  /// Removes the memo identified by [id] from storage.
  Future<void> delete(String id);
}
