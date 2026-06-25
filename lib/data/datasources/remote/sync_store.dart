import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../domain/usecases/sync_memos.dart';

/// [SyncStore] implementation backed by [FlutterSecureStorage].
///
/// Persists lastSyncedAt as an ISO-8601 string under a fixed key.
class SecureStorageSyncStore implements SyncStore {
  const SecureStorageSyncStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kLastSyncedAtKey = 'memo_sync_last_synced_at';

  final FlutterSecureStorage _storage;

  @override
  Future<DateTime?> readLastSyncedAt() async {
    final raw = await _storage.read(key: _kLastSyncedAtKey);
    if (raw == null) return null;
    return DateTime.parse(raw);
  }

  @override
  Future<void> writeLastSyncedAt(DateTime timestamp) async {
    await _storage.write(
      key: _kLastSyncedAtKey,
      value: timestamp.toIso8601String(),
    );
  }
}
