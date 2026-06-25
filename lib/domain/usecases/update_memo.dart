import '../entities/memo.dart';
import '../repositories/memo_repository.dart';

/// Updates an existing memo: refreshes [Memo.updatedAt] to UTC now while
/// preserving the original [Memo.createdAt].
class UpdateMemo {
  const UpdateMemo(this._repository);

  final MemoRepository _repository;

  Future<Memo> call({
    required Memo memo,
    String? title,
    required String content,
    bool clearTitle = false,
  }) async {
    final updated = memo.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now().toUtc(),
      clearTitle: clearTitle,
    );
    await _repository.update(updated);
    return updated;
  }
}
