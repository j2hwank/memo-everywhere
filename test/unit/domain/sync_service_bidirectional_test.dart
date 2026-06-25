// Tests for bidirectional SyncService behavior:
// - Not logged in → all methods are no-ops (no network calls)
// - onMemoSaved pushes via remote update (PUT upsert) when logged in + online
// - onMemoSaved enqueues when offline
// - onMemoDeleted pushes via remote delete when logged in + online
// - onMemoDeleted enqueues delete op when offline
// - syncNow replays queued ops then pulls
// - all errors are swallowed (best-effort)

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/core/services/sync_service.dart';
import 'package:memo_everywhere/data/datasources/remote/memo_remote_datasource.dart';
import 'package:memo_everywhere/data/models/memo_model.dart';
import 'package:memo_everywhere/data/datasources/remote/backend_stt_service.dart';
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

  final testMemo = Memo(
    id: 'memo-123',
    title: 'Title',
    content: 'Content',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

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

    when(() => mockSyncMemos.call()).thenAnswer((_) async {});
    when(() => mockSyncMemos.initialize()).thenAnswer((_) async {});
    when(() => mockRemote.update(any())).thenAnswer((_) async {});
    when(() => mockRemote.delete(any())).thenAnswer((_) async {});
  });

  void buildService() {
    syncService = SyncService(
      syncMemos: mockSyncMemos,
      networkChecker: mockNetwork,
      remoteDataSource: mockRemote,
      tokenStore: mockTokenStore,
    );
  }

  group('T-SVC-001: Not logged in → all methods are no-ops', () {
    setUp(() {
      when(() => mockTokenStore.readAccessToken()).thenAnswer((_) async => null);
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      buildService();
    });

    test('onMemoSaved does not push when not logged in', () async {
      await syncService.onMemoSaved(testMemo);

      verifyNever(() => mockRemote.update(any()));
      verifyNever(() => mockSyncMemos.call());
    });

    test('onMemoDeleted does not call remote delete when not logged in',
        () async {
      await syncService.onMemoDeleted('memo-123');

      verifyNever(() => mockRemote.delete(any()));
    });

    test('syncNow does not pull when not logged in', () async {
      await syncService.syncNow();

      verifyNever(() => mockSyncMemos.call());
    });
  });

  group('T-SVC-002: Logged in + online → push on save', () {
    setUp(() {
      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => 'jwt-token');
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      buildService();
    });

    test('onMemoSaved pushes via remote update (PUT upsert)', () async {
      // Act
      await syncService.onMemoSaved(testMemo);

      // Assert: remote update (PUT /memos/{id}) was called
      final captured =
          verify(() => mockRemote.update(captureAny())).captured;
      expect(captured, hasLength(1));
      final model = captured.first as MemoModel;
      expect(model.id, equals(testMemo.id));
      expect(model.content, equals(testMemo.content));
    });

    test('onMemoSaved does not call syncMemos pull (push only)', () async {
      await syncService.onMemoSaved(testMemo);

      // Pull (syncMemos.call) should NOT be triggered on save — only push
      verifyNever(() => mockSyncMemos.call());
    });
  });

  group('T-SVC-003: Logged in + offline → enqueue for later', () {
    setUp(() {
      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => 'jwt-token');
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      buildService();
    });

    test('onMemoSaved enqueues memo when offline', () async {
      await syncService.onMemoSaved(testMemo);

      verifyNever(() => mockRemote.update(any()));
      expect(syncService.pendingQueueLength, equals(1));
    });

    test('onMemoDeleted enqueues delete op when offline', () async {
      await syncService.onMemoDeleted('memo-123');

      verifyNever(() => mockRemote.delete(any()));
      expect(syncService.pendingQueueLength, equals(1));
    });
  });

  group('T-SVC-004: syncNow replays queue then pulls', () {
    setUp(() {
      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => 'jwt-token');
      buildService();
    });

    test('syncNow replays queued save ops then pulls when online', () async {
      // Enqueue while offline
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      await syncService.onMemoSaved(testMemo);
      expect(syncService.pendingQueueLength, equals(1));

      // Come online
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);

      // Act
      await syncService.syncNow();

      // Assert: queued save was pushed
      verify(() => mockRemote.update(any())).called(1);
      // And pull happened
      verify(() => mockSyncMemos.call()).called(1);
      // Queue is drained
      expect(syncService.pendingQueueLength, equals(0));
    });

    test('syncNow replays queued delete ops then pulls', () async {
      // Enqueue delete while offline
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      await syncService.onMemoDeleted('memo-456');
      expect(syncService.pendingQueueLength, equals(1));

      // Come online
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);

      // Act
      await syncService.syncNow();

      // Assert: queued delete was pushed
      verify(() => mockRemote.delete('memo-456')).called(1);
      // And pull happened
      verify(() => mockSyncMemos.call()).called(1);
      expect(syncService.pendingQueueLength, equals(0));
    });
  });

  group('T-SVC-005: push errors are swallowed (best-effort)', () {
    setUp(() {
      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => 'jwt-token');
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      buildService();
    });

    test('onMemoSaved does not throw when remote update fails', () async {
      when(() => mockRemote.update(any()))
          .thenThrow(Exception('network error'));

      // Should not throw
      expect(() => syncService.onMemoSaved(testMemo), returnsNormally);
      await syncService.onMemoSaved(testMemo);
    });

    test('onMemoDeleted does not throw when remote delete fails', () async {
      when(() => mockRemote.delete(any()))
          .thenThrow(Exception('network error'));

      expect(() => syncService.onMemoDeleted('memo-123'), returnsNormally);
      await syncService.onMemoDeleted('memo-123');
    });
  });

  group('T-SVC-006: onMemoDeleted pushes when logged in + online', () {
    setUp(() {
      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => 'jwt-token');
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      buildService();
    });

    test('onMemoDeleted calls remote delete with the memo id', () async {
      await syncService.onMemoDeleted('my-memo-id');

      verify(() => mockRemote.delete('my-memo-id')).called(1);
    });
  });
}
