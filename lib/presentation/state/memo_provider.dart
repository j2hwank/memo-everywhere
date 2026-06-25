import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/datasources/local/memo_local_datasource.dart';
import '../../data/repositories/memo_repository_impl.dart';
import '../../domain/entities/memo.dart';
import '../../domain/repositories/memo_repository.dart';
import '../../domain/usecases/create_memo.dart';
import '../../domain/usecases/delete_memo.dart';
import '../../domain/usecases/get_memos.dart';
import '../../domain/usecases/update_memo.dart';

part 'memo_provider.g.dart';

@riverpod
MemoLocalDataSource memoLocalDataSource(MemoLocalDataSourceRef ref) {
  return MemoLocalDataSourceImpl();
}

@riverpod
MemoRepository memoRepository(MemoRepositoryRef ref) {
  final dataSource = ref.watch(memoLocalDataSourceProvider);
  return MemoRepositoryImpl(dataSource);
}

/// Async notifier that loads and holds the memos list (updatedAt DESC).
@riverpod
class Memos extends _$Memos {
  @override
  Future<List<Memo>> build() async {
    final repo = ref.watch(memoRepositoryProvider);
    return GetMemos(repo)();
  }
}

/// Notifier that exposes CRUD actions; each action invalidates [memosProvider]
/// so the list rebuilds automatically.
@riverpod
class MemoNotifier extends _$MemoNotifier {
  @override
  void build() {}

  Future<void> create({String? title, required String content}) async {
    final repo = ref.read(memoRepositoryProvider);
    await CreateMemo(repo)(title: title, content: content);
    ref.invalidate(memosProvider);
  }

  Future<void> update({
    required Memo memo,
    String? title,
    required String content,
    bool clearTitle = false,
  }) async {
    final repo = ref.read(memoRepositoryProvider);
    await UpdateMemo(repo)(
      memo: memo,
      title: title,
      content: content,
      clearTitle: clearTitle,
    );
    ref.invalidate(memosProvider);
  }

  Future<void> delete(String id) async {
    final repo = ref.read(memoRepositoryProvider);
    await DeleteMemo(repo)(id);
    ref.invalidate(memosProvider);
  }
}
