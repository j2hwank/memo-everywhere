// Tests for durable offline queue persistence in SyncService.
//
// REQ: Pending ops must survive a force-quit/restart. SyncService must
// persist each op to PendingOpStore so a fresh SyncService instance
// (constructed with the same store) replays them on the next syncNow().
//
// All tests use InMemoryPendingOpStore — no real Hive runtime needed.

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
  late InMemoryPendingOpStore store;

  final testMemo = Memo(
    id: 'memo-persist-1',
    title: 'Persistent',
    content: 'Should survive restart',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
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
    store = InMemoryPendingOpStore();

    when(() => mockSyncMemos.call()).thenAnswer((_) async {});
    when(() => mockSyncMemos.initialize()).thenAnswer((_) async {});
    when(() => mockRemote.update(any())).thenAnswer((_) async {});
    when(() => mockRemote.delete(any())).thenAnswer((_) async {});
    when(() => mockTokenStore.readAccessToken())
        .thenAnswer((_) async => 'jwt-token');
  });

  SyncService buildService() => SyncService(
        syncMemos: mockSyncMemos,
        networkChecker: mockNetwork,
        remoteDataSource: mockRemote,
        tokenStore: mockTokenStore,
        pendingOpStore: store,
      );

  // ─── T-PERSIST-001 ───────────────────────────────────────────────────────
  group('T-PERSIST-001: enqueue while offline persists op to store', () {
    test('onMemoSaved while offline appends a PendingSaveOp to the store',
        () async {
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      final svc = buildService();

      await svc.onMemoSaved(testMemo);

      final entries = await store.loadAll();
      expect(entries, hasLength(1));
      expect(entries.first, isA<PendingSaveOp>());
      final op = entries.first as PendingSaveOp;
      expect(op.memo.id, equals(testMemo.id));
      expect(op.memo.content, equals(testMemo.content));
      expect(op.memo.updatedAt, equals(testMemo.updatedAt));
    });

    test('onMemoDeleted while offline appends a PendingDeleteOp to the store',
        () async {
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      final svc = buildService();

      await svc.onMemoDeleted('memo-del-1');

      final entries = await store.loadAll();
      expect(entries, hasLength(1));
      expect(entries.first, isA<PendingDeleteOp>());
      final op = entries.first as PendingDeleteOp;
      expect(op.id, equals('memo-del-1'));
    });
  });

  // ─── T-PERSIST-002 ───────────────────────────────────────────────────────
  group('T-PERSIST-002: restart-replay — fresh SyncService replays persisted ops',
      () {
    test(
        'save op persisted in session 1 is replayed by a fresh SyncService in session 2',
        () async {
      // Session 1: enqueue while offline
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      final session1 = buildService();
      await session1.onMemoSaved(testMemo);

      // Verify op is in the shared store (simulates persistent storage)
      expect(await store.loadAll(), hasLength(1));

      // Session 2: new SyncService instance (same store), now online
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      final session2 = buildService(); // same `store` injected

      await session2.syncNow();

      // Assert: the op was replayed via remote.update
      final captured = verify(() => mockRemote.update(captureAny())).captured;
      expect(captured, hasLength(1));
      final model = captured.first as MemoModel;
      expect(model.id, equals(testMemo.id));
      expect(model.content, equals(testMemo.content));
      expect(model.updatedAt, equals(testMemo.updatedAt));
    });

    test(
        'delete op persisted in session 1 is replayed by fresh SyncService in session 2',
        () async {
      // Session 1
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      final session1 = buildService();
      await session1.onMemoDeleted('memo-xyz');

      // Session 2
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      final session2 = buildService();
      await session2.syncNow();

      verify(() => mockRemote.delete('memo-xyz')).called(1);
    });
  });

  // ─── T-PERSIST-003 ───────────────────────────────────────────────────────
  group('T-PERSIST-003: syncNow clears the persisted queue after replay', () {
    test('store is empty after a successful syncNow replay pass', () async {
      // Enqueue 2 ops while offline
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      final svc = buildService();
      await svc.onMemoSaved(testMemo);
      await svc.onMemoDeleted('memo-del-2');
      expect(await store.loadAll(), hasLength(2));

      // Come online and sync
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      await svc.syncNow();

      // Store must be cleared
      expect(await store.loadAll(), isEmpty);
    });

    test('pendingQueueLength returns 0 after syncNow drains the queue',
        () async {
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      final svc = buildService();
      await svc.onMemoSaved(testMemo);
      expect(svc.pendingQueueLength, equals(1));

      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      await svc.syncNow();

      expect(svc.pendingQueueLength, equals(0));
    });
  });

  // ─── T-PERSIST-004 ───────────────────────────────────────────────────────
  group('T-PERSIST-004: not-logged-in path persists nothing', () {
    test('onMemoSaved while not logged in does NOT write to the store',
        () async {
      when(() => mockTokenStore.readAccessToken()).thenAnswer((_) async => null);
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      final svc = buildService();

      await svc.onMemoSaved(testMemo);

      expect(await store.loadAll(), isEmpty);
      expect(svc.pendingQueueLength, equals(0));
    });

    test('onMemoDeleted while not logged in does NOT write to the store',
        () async {
      when(() => mockTokenStore.readAccessToken()).thenAnswer((_) async => null);
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      final svc = buildService();

      await svc.onMemoDeleted('any-id');

      expect(await store.loadAll(), isEmpty);
    });
  });

  // ─── T-PERSIST-005 ───────────────────────────────────────────────────────
  group(
      'T-PERSIST-005: push-failure path also persists op (best-effort enqueue)',
      () {
    test(
        'onMemoSaved when online but remote throws still persists op to store',
        () async {
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      when(() => mockRemote.update(any()))
          .thenThrow(Exception('network failure'));
      final svc = buildService();

      await svc.onMemoSaved(testMemo);

      final entries = await store.loadAll();
      expect(entries, hasLength(1));
      expect(entries.first, isA<PendingSaveOp>());
    });
  });

  // ─── T-PERSIST-006 ───────────────────────────────────────────────────────
  group('T-PERSIST-006: FIFO ordering is preserved across restart', () {
    test('multiple ops are replayed in insertion order', () async {
      final memo1 = Memo(
        id: 'a',
        title: null,
        content: 'first',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final memo2 = Memo(
        id: 'b',
        title: null,
        content: 'second',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      final session1 = buildService();
      await session1.onMemoSaved(memo1);
      await session1.onMemoDeleted('del-x');
      await session1.onMemoSaved(memo2);

      // Fresh instance — replay
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      final session2 = buildService();
      await session2.syncNow();

      // FIFO: update(memo1), delete(del-x), update(memo2), then pull
      verifyInOrder([
        () => mockRemote.update(any()),
        () => mockRemote.delete('del-x'),
        () => mockRemote.update(any()),
        () => mockSyncMemos.call(),
      ]);
    });
  });
}
