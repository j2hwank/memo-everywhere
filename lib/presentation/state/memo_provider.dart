import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/network/dio_config.dart';
import '../../core/network/network_checker.dart';
import '../../core/services/sync_service.dart';
import '../../data/datasources/local/memo_local_datasource.dart';
import '../../data/datasources/remote/memo_remote_datasource.dart';
import '../../data/datasources/remote/sync_store.dart';
import '../../data/repositories/memo_repository_impl.dart';
import '../../domain/entities/memo.dart';
import '../../domain/repositories/memo_repository.dart';
import '../../domain/usecases/create_memo.dart';
import '../../domain/usecases/delete_memo.dart';
import '../../domain/usecases/get_memos.dart';
import '../../domain/usecases/search_memos.dart';
import '../../domain/usecases/sync_memos.dart';
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

// @MX:ANCHOR: [AUTO] memoRemoteDataSourceProvider — remote datasource singleton
// @MX:REASON: Used by syncMemosProvider and syncServiceProvider; fan_in >= 2.
/// Provider for the remote memo datasource (Dio-backed).
final memoRemoteDataSourceProvider = Provider<MemoRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return MemoRemoteDataSourceImpl(dio: dio);
});

/// Provider for [NetworkChecker] (connectivity_plus backed).
final networkCheckerProvider = Provider<NetworkChecker>((ref) {
  return ConnectivityNetworkChecker();
});

/// Provider for [SyncStore] (secure storage backed).
final syncStoreProvider = Provider<SyncStore>((ref) {
  return const SecureStorageSyncStore();
});

/// Provider for [SyncMemos] use case.
final syncMemosProvider = Provider<SyncMemos>((ref) {
  return SyncMemos(
    localRepo: ref.watch(memoRepositoryProvider),
    remoteDatasource: ref.watch(memoRemoteDataSourceProvider),
    syncStore: ref.watch(syncStoreProvider),
  );
});

// @MX:ANCHOR: [AUTO] syncServiceProvider — sync coordinator singleton
// @MX:REASON: Consumed by MemoNotifier (save/delete), HomePage (foreground),
// and auth listener; fan_in >= 3.
/// Provider for [SyncService].
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    syncMemos: ref.watch(syncMemosProvider),
    networkChecker: ref.watch(networkCheckerProvider),
    remoteDataSource: ref.watch(memoRemoteDataSourceProvider),
    tokenStore: ref.watch(secureTokenStoreProvider),
  );
});

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
/// so the list rebuilds automatically, and triggers SyncService for push sync.
@riverpod
class MemoNotifier extends _$MemoNotifier {
  @override
  void build() {}

  Future<void> create({String? title, required String content}) async {
    final repo = ref.read(memoRepositoryProvider);
    final memo = await CreateMemo(repo)(title: title, content: content);
    ref.invalidate(memosProvider);
    // Push to remote if logged in + online (best-effort, never throws)
    await ref.read(syncServiceProvider).onMemoSaved(memo);
  }

  Future<void> update({
    required Memo memo,
    String? title,
    required String content,
    bool clearTitle = false,
  }) async {
    final repo = ref.read(memoRepositoryProvider);
    final updated = await UpdateMemo(repo)(
      memo: memo,
      title: title,
      content: content,
      clearTitle: clearTitle,
    );
    ref.invalidate(memosProvider);
    // Push to remote if logged in + online (best-effort, never throws)
    await ref.read(syncServiceProvider).onMemoSaved(updated);
  }

  Future<void> delete(String id) async {
    final repo = ref.read(memoRepositoryProvider);
    await DeleteMemo(repo)(id);
    ref.invalidate(memosProvider);
    // Push soft-delete to remote if logged in + online (best-effort)
    await ref.read(syncServiceProvider).onMemoDeleted(id);
  }
}

/// Holds the current search query. Empty string = no filter.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Combines [memosProvider] with [searchQueryProvider] to produce a filtered list.
/// Passes loading/error states through unchanged.
@riverpod
AsyncValue<List<Memo>> filteredMemos(FilteredMemosRef ref) {
  final query = ref.watch(searchQueryProvider);
  final memosAsync = ref.watch(memosProvider);
  return memosAsync.whenData((memos) => const SearchMemos()(query, memos));
}
