// Tests for MemoNotifier triggering SyncService after CRUD ops:
// - create → SyncService.onMemoSaved
// - update → SyncService.onMemoSaved
// - delete → SyncService.onMemoDeleted

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/core/services/sync_service.dart';
import 'package:memo_everywhere/data/datasources/local/memo_local_datasource.dart';
import 'package:memo_everywhere/data/models/memo_model.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/domain/repositories/memo_repository.dart';
import 'package:memo_everywhere/presentation/state/memo_provider.dart';

class MockMemoRepository extends Mock implements MemoRepository {}

class MockSyncService extends Mock implements SyncService {}

class MockMemoLocalDataSource extends Mock implements MemoLocalDataSource {}

void main() {
  late MockMemoRepository mockRepo;
  late MockSyncService mockSyncService;

  final testMemo = Memo(
    id: 'memo-001',
    title: 'Test',
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
    mockRepo = MockMemoRepository();
    mockSyncService = MockSyncService();

    when(() => mockRepo.create(any())).thenAnswer((_) async {});
    when(() => mockRepo.update(any())).thenAnswer((_) async {});
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});
    when(() => mockRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockSyncService.onMemoSaved(any())).thenAnswer((_) async {});
    when(() => mockSyncService.onMemoDeleted(any())).thenAnswer((_) async {});
    when(() => mockSyncService.syncNow()).thenAnswer((_) async {});
  });

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        memoRepositoryProvider.overrideWithValue(mockRepo),
        syncServiceProvider.overrideWithValue(mockSyncService),
      ],
    );
  }

  group('T-NOTIFIER-001: MemoNotifier.create triggers SyncService.onMemoSaved',
      () {
    test('create calls onMemoSaved with the newly created memo', () async {
      // Arrange
      final container = buildContainer();
      addTearDown(container.dispose);

      // Act
      await container
          .read(memoNotifierProvider.notifier)
          .create(content: 'New content');

      // Assert
      verify(() => mockSyncService.onMemoSaved(any())).called(1);
    });
  });

  group('T-NOTIFIER-002: MemoNotifier.update triggers SyncService.onMemoSaved',
      () {
    test('update calls onMemoSaved with the updated memo', () async {
      // Arrange
      final container = buildContainer();
      addTearDown(container.dispose);

      // Act
      await container.read(memoNotifierProvider.notifier).update(
            memo: testMemo,
            content: 'Updated content',
          );

      // Assert
      verify(() => mockSyncService.onMemoSaved(any())).called(1);
    });
  });

  group(
      'T-NOTIFIER-003: MemoNotifier.delete triggers SyncService.onMemoDeleted',
      () {
    test('delete calls onMemoDeleted with the memo id', () async {
      // Arrange
      final container = buildContainer();
      addTearDown(container.dispose);

      // Act
      await container
          .read(memoNotifierProvider.notifier)
          .delete(testMemo.id);

      // Assert
      verify(() => mockSyncService.onMemoDeleted(testMemo.id)).called(1);
    });
  });
}
