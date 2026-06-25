// Shared test helpers for widget tests that need to suppress sync behavior.
//
// Import this file and include syncProviderOverrides in ProviderScope.overrides
// to prevent HiveError / network calls from real providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memo_everywhere/core/network/dio_config.dart';
import 'package:memo_everywhere/core/services/sync_service.dart';
import 'package:memo_everywhere/data/datasources/remote/memo_remote_datasource.dart';
import 'package:memo_everywhere/data/datasources/remote/backend_stt_service.dart';
import 'package:memo_everywhere/data/models/memo_model.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/domain/usecases/sync_memos.dart';
import 'package:memo_everywhere/presentation/state/memo_provider.dart';

// ---------------------------------------------------------------------------
// No-op fakes for sync infrastructure
// ---------------------------------------------------------------------------

/// No-op [NetworkChecker] — always returns false (offline) to avoid real calls.
class FakeNetworkChecker implements NetworkChecker {
  @override
  Future<bool> isConnected() async => false;
}

/// No-op [SecureTokenStore] — always returns null token (not logged in).
class FakeSecureTokenStore implements SecureTokenStore {
  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> writeAccessToken(String accessToken) async {}

  @override
  Future<void> writeEmail(String email) async {}

  @override
  Future<String?> readEmail() async => null;

  @override
  Future<void> clear() async {}
}

/// No-op [SyncStore] — never persists anything.
class FakeSyncStore implements SyncStore {
  @override
  Future<DateTime?> readLastSyncedAt() async => null;

  @override
  Future<void> writeLastSyncedAt(DateTime timestamp) async {}
}

/// No-op [MemoRemoteDataSource] — never hits the network.
class FakeMemoRemoteDataSource implements MemoRemoteDataSource {
  @override
  Future<List<MemoModel>> getAll() async => [];

  @override
  Future<List<MemoModel>> getSince(DateTime since) async => [];

  @override
  Future<void> create(MemoModel model) async {}

  @override
  Future<void> update(MemoModel model) async {}

  @override
  Future<void> delete(String id) async {}
}

/// Provider overrides to suppress sync in widget tests.
///
/// Overrides [syncServiceProvider] with a no-op [FakeSyncService] so that
/// [HomePage._triggerSync] does not hit Hive or the network during tests.
///
/// Usage:
/// ```dart
/// ProviderScope(
///   overrides: [...syncProviderOverrides, ...yourOtherOverrides],
///   child: MaterialApp(home: YourWidget()),
/// )
/// ```
List<Override> get syncProviderOverrides => [
      networkCheckerProvider.overrideWithValue(FakeNetworkChecker()),
      secureTokenStoreProvider.overrideWithValue(FakeSecureTokenStore()),
      syncStoreProvider.overrideWithValue(FakeSyncStore()),
      memoRemoteDataSourceProvider
          .overrideWithValue(FakeMemoRemoteDataSource()),
      // Override the top-level coordinator so _triggerSync is a no-op
      syncServiceProvider.overrideWithValue(FakeSyncService()),
    ];

/// A [SyncService] that does nothing — useful for testing [MemoNotifier]
/// in isolation without a real [SyncService].
class FakeSyncService implements SyncService {
  @override
  int get pendingQueueLength => 0;

  @override
  Future<void> onMemoSaved(Memo memo) async {}

  @override
  Future<void> onMemoDeleted(String id) async {}

  @override
  Future<void> onAppForeground() async {}

  @override
  Future<void> syncNow() async {}
}
