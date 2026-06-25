import 'package:uuid/uuid.dart';
import '../entities/memo.dart';
import '../repositories/memo_repository.dart';

/// Creates a new [Memo] with a generated id and UTC timestamps, then persists
/// it via [MemoRepository.create].
class CreateMemo {
  const CreateMemo(this._repository, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final MemoRepository _repository;
  final Uuid _uuid;

  Future<Memo> call({String? title, required String content}) async {
    final now = DateTime.now().toUtc();
    final memo = Memo(
      id: _uuid.v4(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.create(memo);
    return memo;
  }
}
