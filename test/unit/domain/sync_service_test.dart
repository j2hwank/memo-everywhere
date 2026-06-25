import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/core/services/sync_service.dart';
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

    // Logged in by default for these tests
    when(() => mockTokenStore.readAccessToken())
        .thenAnswer((_) async => 'jwt-token');
    when(() => mockSyncMemos.call()).thenAnswer((_) async {});
    when(() => mockSyncMemos.initialize()).thenAnswer((_) async {});
    when(() => mockRemote.update(any())).thenAnswer((_) async {});
    when(() => mockRemote.delete(any())).thenAnswer((_) async {});

    syncService = SyncService(
      syncMemos: mockSyncMemos,
      networkChecker: mockNetwork,
      remoteDataSource: mockRemote,
      tokenStore: mockTokenStore,
    );
  });

  group('SyncService - REQ-B-009 foreground trigger', () {
    test('onAppForeground calls pull sync when logged in + network available',
        () async {
      // Arrange
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);

      // Act
      await syncService.onAppForeground();

      // Assert: pull happened (no queued items to push)
      verify(() => mockSyncMemos.call()).called(1);
    });

    test('onAppForeground does NOT sync when offline', () async {
      // Arrange
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);

      // Act
      await syncService.onAppForeground();

      // Assert
      verifyNever(() => mockSyncMemos.call());
    });
  });

  group('SyncService - REQ-B-009 memo save trigger', () {
    test('onMemoSaved pushes to remote when logged in + online', () async {
      // Arrange
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      final memo = Memo(
        id: 'memo-1',
        title: null,
        content: 'test',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      // Act
      await syncService.onMemoSaved(memo);

      // Assert: pushed via remote update (no pull on save)
      verify(() => mockRemote.update(any())).called(1);
    });

    test('onMemoSaved queues memo when offline (AC-10)', () async {
      // Arrange
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      final memo = Memo(
        id: 'memo-offline',
        title: null,
        content: 'offline memo',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      // Act
      await syncService.onMemoSaved(memo);

      // Assert: not pushed, memo is in queue
      verifyNever(() => mockRemote.update(any()));
      expect(syncService.pendingQueueLength, equals(1));
    });
  });

  group('SyncService - REQ-B-010 offline queue replay', () {
    test('syncNow flushes offline queue then pulls on reconnect', () async {
      // Arrange: add memo to queue while offline
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      final memo1 = Memo(
        id: 'q1',
        title: null,
        content: 'queued',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await syncService.onMemoSaved(memo1);
      expect(syncService.pendingQueueLength, equals(1));

      // Now back online
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);

      // Act
      await syncService.onAppForeground();

      // Assert: queued op was pushed, pull happened, queue is drained
      verify(() => mockRemote.update(any())).called(1);
      verify(() => mockSyncMemos.call()).called(1);
      expect(syncService.pendingQueueLength, equals(0));
    });
  });
}
