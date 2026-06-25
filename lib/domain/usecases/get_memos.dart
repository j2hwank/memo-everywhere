import '../entities/memo.dart';
import '../repositories/memo_repository.dart';

/// Retrieves all memos from [MemoRepository], sorted by [Memo.updatedAt] DESC.
///
/// The repository implementation is responsible for the sort; this usecase
/// delegates and returns whatever the repository provides.
class GetMemos {
  const GetMemos(this._repository);

  final MemoRepository _repository;

  // @MX:NOTE sort by updatedAt DESC — newest first (enforced in repo impl)
  Future<List<Memo>> call() => _repository.getAll();
}
