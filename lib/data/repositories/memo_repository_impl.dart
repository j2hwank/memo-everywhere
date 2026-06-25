import '../../domain/entities/memo.dart';
import '../../domain/repositories/memo_repository.dart';
import '../datasources/local/memo_local_datasource.dart';
import '../models/memo_model.dart';

/// Concrete implementation of [MemoRepository] backed exclusively by Hive via
/// [MemoLocalDataSource]. No network calls are made.
class MemoRepositoryImpl implements MemoRepository {
  const MemoRepositoryImpl(this._dataSource);

  final MemoLocalDataSource _dataSource;

  // @MX:NOTE sort by updatedAt DESC — newest first; Hive does not guarantee order.
  @override
  Future<List<Memo>> getAll() async {
    final models = await _dataSource.getAll();
    final memos = models.map((m) => m.toMemo()).toList();
    memos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return memos;
  }

  @override
  Future<void> create(Memo memo) async {
    await _dataSource.create(MemoModel.fromMemo(memo));
  }

  @override
  Future<void> update(Memo memo) async {
    await _dataSource.update(MemoModel.fromMemo(memo));
  }

  @override
  Future<void> delete(String id) async {
    await _dataSource.delete(id);
  }
}
