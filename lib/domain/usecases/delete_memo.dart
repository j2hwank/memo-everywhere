import '../repositories/memo_repository.dart';

/// Deletes the memo identified by [id] from persistent storage.
class DeleteMemo {
  const DeleteMemo(this._repository);

  final MemoRepository _repository;

  Future<void> call(String id) => _repository.delete(id);
}
