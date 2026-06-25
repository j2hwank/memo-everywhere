// Tests for SyncService in-flight overlap guard (T-SVC-OVERLAP-*).
//
// REQ: If syncNow() is called again while a previous syncNow() is still
// running, the second call must return immediately without triggering a
// second underlying SyncMemos.call(). This prevents concurrent syncs from
// hammering the backend when the 30-second poll fires during a slow network.
//
// Technique: Use a Completer to hold the first SyncMemos.call() open, verify
// that a second syncNow() call does NOT invoke call() again, then complete
// the first call and confirm it resumes normally.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/core/services/sync_service.dart';
import 'package:memo_everywhere/data/datasources/local/pending_op_store.dart';
import 'package:memo_everywhere/data/datasources/remote/backend_stt_service.dart';
import 'package:memo_everywhere/data/datasources/remote/memo_remote_datasource.dart';
import 'package:memo_everywhere/data/models/memo_model.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/domain/usecases/sync_memos.dart';

class MockSyncMemos extends Mock implements SyncMemos {}

class MockNetworkChecker extends Mock implements NetworkChecker {}

class MockMemoRemoteDataSource extends Mock implements MemoRemoteDataSource {}

class MockSecureTokenStore extends Mock implements SecureTokenStore {}

void main() {
  late MockSyncMemos mockSyncMemos;
  late MockNetworkChecker mockNetwork;
  late MockMemoRemoteDataSource mockRemote;
  late MockSecureTokenStore mockTokenStore;
  late SyncService syncService;

  setUpAll(() {
    registerFallbackValue(Memo(
      id: 'fallback',
      title: null,
      content: '',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ));
    registerFallbackValue(MemoModel(
      id: 'fallback',
      title: null,
      content: '',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ));
  });

  setUp(() {
    mockSyncMemos = MockSyncMemos();
    mockNetwork = MockNetworkChecker();
    mockRemote = MockMemoRemoteDataSource();
    mockTokenStore = MockSecureTokenStore();

    // Default: logged in, online, mocks behave normally
    when(() => mockTokenStore.readAccessToken())
        .thenAnswer((_) async => 'jwt-token');
    when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
    when(() => mockSyncMemos.initialize()).thenAnswer((_) async {});
    when(() => mockRemote.update(any())).thenAnswer((_) async {});
    when(() => mockRemote.delete(any())).thenAnswer((_) async {});

    syncService = SyncService(
      syncMemos: mockSyncMemos,
      networkChecker: mockNetwork,
      remoteDataSource: mockRemote,
      tokenStore: mockTokenStore,
      pendingOpStore: InMemoryPendingOpStore(),
    );
  });

  group('T-SVC-OVERLAP-001: in-flight syncNow guard', () {
    test(
        'second syncNow() while first is in-flight does not invoke SyncMemos.call() a second time',
        () async {
      // Arrange: use a Completer to hold the first SyncMemos.call() open so
      // we can verify the second syncNow() is a no-op while it is pending.
      final completer = Completer<void>();
      when(() => mockSyncMemos.call()).thenAnswer((_) => completer.future);

      // Act: start first sync (does not await — it hangs on completer)
      final firstSync = syncService.syncNow();

      // Give the first sync time to reach SyncMemos.call() (which is blocked on
      // the completer). syncNow() contains several awaits before call():
      //   1. _isLoggedIn()
      //   2. isConnected()
      //   3. _syncMemos.initialize()
      // Each await yields to the event loop; pump the event loop multiple times
      // to ensure all intermediate awaits have settled and we are inside call().
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      // Second syncNow() should be a no-op (in-flight guard).
      await syncService.syncNow();

      // Unblock the first sync and let it finish cleanly.
      completer.complete();
      await firstSync;

      // Assert: SyncMemos.call() was invoked exactly once total —
      // the second syncNow() (in-flight guard) did NOT trigger a second call().
      verify(() => mockSyncMemos.call()).called(1);
    });

    test('syncNow() can run again after the previous call completes', () async {
      // Arrange: normal fast completion
      when(() => mockSyncMemos.call()).thenAnswer((_) async {});

      // Act: run twice sequentially
      await syncService.syncNow();
      await syncService.syncNow();

      // Assert: both were allowed through because the first finished before the second started.
      verify(() => mockSyncMemos.call()).called(2);
    });

    test(
        'overlap guard resets even if SyncMemos.call() throws (finally-based reset)',
        () async {
      // Arrange: first call throws
      var callCount = 0;
      when(() => mockSyncMemos.call()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw Exception('network error');
      });

      // Act: first sync fails silently (best-effort)
      await syncService.syncNow();

      // Second sync should be allowed (guard was reset in finally)
      await syncService.syncNow();

      // Assert: both calls went through
      expect(callCount, equals(2));
    });
  });
}
