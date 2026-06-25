import '../repositories/memo_repository.dart';
import '../../data/datasources/remote/memo_remote_datasource.dart';

/// Synchronize local memos with the remote server using Last-Write-Wins (LWW).
///
/// Algorithm:
/// 1. Fetch remote changes since last sync.
/// 2. Merge with local memos using LWW (newer updated_at wins).
/// 3. Create locally if remote memo not found; update if remote is newer.
///
/// REQ-B-004: LWW conflict resolution.
/// REQ-B-005: Incremental sync via getSince().
class SyncMemos {
  SyncMemos({
    required MemoRepository localRepo,
    required MemoRemoteDataSource remoteDatasource,
    DateTime? lastSyncedAt,
  })  : _localRepo = localRepo,
        _remoteDatasource = remoteDatasource,
        _lastSyncedAt = lastSyncedAt;

  final MemoRepository _localRepo;
  final MemoRemoteDataSource _remoteDatasource;
  DateTime? _lastSyncedAt;

  /// Execute the sync. Returns normally on success, throws on failure.
  Future<void> call() async {
    final since = _lastSyncedAt;
    final remoteModels = since != null
        ? await _remoteDatasource.getSince(since)
        : await _remoteDatasource.getAll();

    final localMemos = await _localRepo.getAll();
    final localById = {for (final m in localMemos) m.id: m};

    for (final remote in remoteModels) {
      final local = localById[remote.id];
      if (local == null) {
        // New memo from server → create locally
        await _localRepo.create(remote.toMemo());
      } else if (remote.updatedAt.isAfter(local.updatedAt)) {
        // Remote is newer → overwrite local (LWW)
        await _localRepo.update(remote.toMemo());
      }
      // else: local is newer or equal → keep local (server wins on PUT; here we keep local)
    }

    _lastSyncedAt = DateTime.now().toUtc();
  }
}
