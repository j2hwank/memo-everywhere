// Tests for bidirectional SyncMemos behavior:
// - Deleted remote memos (deleted_at != null) are deleted locally
// - lastSyncedAt is persisted via a SyncStore abstraction
// - lastSyncedAt is loaded on construction to resume incremental sync

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/data/datasources/remote/memo_remote_datasource.dart';
import 'package:memo_everywhere/data/models/memo_model.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/domain/repositories/memo_repository.dart';
import 'package:memo_everywhere/domain/usecases/sync_memos.dart';

class MockMemoRepository extends Mock implements MemoRepository {}

class MockMemoRemoteDataSource extends Mock implements MemoRemoteDataSource {}

class MockSyncStore extends Mock implements SyncStore {}

void main() {
  late MockMemoRepository mockRepo;
  late MockMemoRemoteDataSource mockRemote;
  late MockSyncStore mockStore;

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
    mockRepo = MockMemoRepository();
    mockRemote = MockMemoRemoteDataSource();
    mockStore = MockSyncStore();

    // Default: no stored lastSyncedAt
    when(() => mockStore.readLastSyncedAt()).thenAnswer((_) async => null);
    when(() => mockStore.writeLastSyncedAt(any())).thenAnswer((_) async {});
  });

  SyncMemos buildUseCase({DateTime? lastSyncedAt}) {
    return SyncMemos(
      localRepo: mockRepo,
      remoteDatasource: mockRemote,
      syncStore: mockStore,
      lastSyncedAt: lastSyncedAt,
    );
  }

  group('SyncMemos bidirectional — deletion handling', () {
    test('T-SYNC-001: remote memo with deleted_at → deleted locally if present',
        () async {
      // Arrange
      final now = DateTime.utc(2026, 1, 1);
      final deletedAt = DateTime.utc(2026, 6, 20);

      final localMemo = Memo(
        id: 'memo-to-delete',
        title: 'Will be deleted',
        content: 'content',
        createdAt: now,
        updatedAt: now,
      );

      final remoteDeletedModel = MemoModel(
        id: 'memo-to-delete',
        title: 'Will be deleted',
        content: 'content',
        createdAt: now,
        updatedAt: deletedAt,
        deletedAt: deletedAt,
      );

      final useCase = buildUseCase(lastSyncedAt: DateTime.utc(2025, 1, 1));
      when(() => mockRepo.getAll()).thenAnswer((_) async => [localMemo]);
      when(() => mockRemote.getSince(any()))
          .thenAnswer((_) async => [remoteDeletedModel]);
      when(() => mockRepo.delete(any())).thenAnswer((_) async {});

      // Act
      await useCase.call();

      // Assert: local memo should be deleted, not updated
      verify(() => mockRepo.delete('memo-to-delete')).called(1);
      verifyNever(() => mockRepo.update(any()));
      verifyNever(() => mockRepo.create(any()));
    });

    test(
        'T-SYNC-002: remote deleted memo not in local → no local action needed',
        () async {
      // Arrange
      final now = DateTime.utc(2026, 1, 1);
      final deletedAt = DateTime.utc(2026, 6, 20);

      final remoteDeletedModel = MemoModel(
        id: 'ghost-memo',
        title: null,
        content: '',
        createdAt: now,
        updatedAt: deletedAt,
        deletedAt: deletedAt,
      );

      final useCase = buildUseCase(lastSyncedAt: DateTime.utc(2025, 1, 1));
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRemote.getSince(any()))
          .thenAnswer((_) async => [remoteDeletedModel]);

      // Act
      await useCase.call();

      // Assert: no create, no update, no delete needed
      verifyNever(() => mockRepo.delete(any()));
      verifyNever(() => mockRepo.create(any()));
      verifyNever(() => mockRepo.update(any()));
    });

    test('T-SYNC-003: non-deleted remote memo follows existing LWW logic',
        () async {
      // Arrange
      final older = DateTime.utc(2026, 1, 1);
      final newer = DateTime.utc(2026, 1, 2);

      final localMemo = Memo(
        id: 'memo-1',
        title: 'Local',
        content: 'Old content',
        createdAt: older,
        updatedAt: older,
      );

      // Remote is newer, no deleted_at
      final remoteModel = MemoModel(
        id: 'memo-1',
        title: 'Remote',
        content: 'New content',
        createdAt: older,
        updatedAt: newer,
        deletedAt: null,
      );

      final useCase = buildUseCase(lastSyncedAt: DateTime.utc(2025, 1, 1));
      when(() => mockRepo.getAll()).thenAnswer((_) async => [localMemo]);
      when(() => mockRemote.getSince(any()))
          .thenAnswer((_) async => [remoteModel]);
      when(() => mockRepo.update(any())).thenAnswer((_) async {});

      // Act
      await useCase.call();

      // Assert: updated (LWW — remote newer)
      verify(() => mockRepo.update(any())).called(1);
      verifyNever(() => mockRepo.delete(any()));
    });
  });

  group('SyncMemos bidirectional — lastSyncedAt persistence', () {
    test('T-SYNC-004: lastSyncedAt is written to store after successful sync',
        () async {
      // Arrange
      final useCase = buildUseCase();
      when(() => mockRemote.getAll()).thenAnswer((_) async => []);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);

      // Act
      await useCase.call();

      // Assert: store.writeLastSyncedAt was called
      final captured =
          verify(() => mockStore.writeLastSyncedAt(captureAny())).captured;
      expect(captured, hasLength(1));
      expect(captured.first, isA<DateTime>());
    });

    test(
        'T-SYNC-005: when store has lastSyncedAt, getSince is used (incremental)',
        () async {
      // Arrange
      final storedAt = DateTime.utc(2026, 6, 1);
      when(() => mockStore.readLastSyncedAt())
          .thenAnswer((_) async => storedAt);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRemote.getSince(any())).thenAnswer((_) async => []);

      // Create with no initial lastSyncedAt — should load from store
      final useCase = SyncMemos(
        localRepo: mockRepo,
        remoteDatasource: mockRemote,
        syncStore: mockStore,
      );

      // Act: call to initialize from store, then sync
      await useCase.initialize();
      await useCase.call();

      // Assert: getSince was called with the stored timestamp
      final captured =
          verify(() => mockRemote.getSince(captureAny())).captured;
      expect(captured, hasLength(1));
      expect(captured.first, equals(storedAt));
    });

    test('T-SYNC-006: when no stored lastSyncedAt, getAll is used (full sync)',
        () async {
      // Arrange
      when(() => mockStore.readLastSyncedAt()).thenAnswer((_) async => null);
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRemote.getAll()).thenAnswer((_) async => []);

      final useCase = SyncMemos(
        localRepo: mockRepo,
        remoteDatasource: mockRemote,
        syncStore: mockStore,
      );

      // Act
      await useCase.initialize();
      await useCase.call();

      // Assert: getAll was used (no getSince)
      verify(() => mockRemote.getAll()).called(1);
      verifyNever(() => mockRemote.getSince(any()));
    });
  });
}
