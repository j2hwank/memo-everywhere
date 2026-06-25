import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/core/services/sync_service.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/domain/usecases/sync_memos.dart';

class MockSyncMemos extends Mock implements SyncMemos {}
class MockNetworkChecker extends Mock implements NetworkChecker {}

void main() {
  late MockSyncMemos mockSyncMemos;
  late MockNetworkChecker mockNetwork;
  late SyncService syncService;

  setUpAll(() {
    registerFallbackValue(Memo(
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
    syncService = SyncService(
      syncMemos: mockSyncMemos,
      networkChecker: mockNetwork,
    );

    when(() => mockSyncMemos.call()).thenAnswer((_) async {});
  });

  group('SyncService - REQ-B-009 foreground trigger', () {
    test('onAppForeground calls sync when network is available (AC-9)', () async {
      // Arrange
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);

      // Act
      await syncService.onAppForeground();

      // Assert
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
    test('onMemoSaved calls sync when online (AC-9)', () async {
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

      // Assert
      verify(() => mockSyncMemos.call()).called(1);
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

      // Assert: sync was NOT called, memo is in queue
      verifyNever(() => mockSyncMemos.call());
      expect(syncService.pendingQueueLength, equals(1));
    });
  });

  group('SyncService - REQ-B-010 offline queue replay', () {
    test('onAppForeground flushes offline queue on reconnect (AC-10)', () async {
      // Arrange: add memos to queue while offline
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

      // Assert: queue is flushed and sync was called
      verify(() => mockSyncMemos.call()).called(1);
      expect(syncService.pendingQueueLength, equals(0));
    });
  });
}
