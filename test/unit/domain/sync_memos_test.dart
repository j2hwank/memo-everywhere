import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/domain/repositories/memo_repository.dart';
import 'package:memo_everywhere/data/datasources/remote/memo_remote_datasource.dart';
import 'package:memo_everywhere/data/models/memo_model.dart';
import 'package:memo_everywhere/domain/usecases/sync_memos.dart';

class MockMemoRepository extends Mock implements MemoRepository {}
class MockMemoRemoteDataSource extends Mock implements MemoRemoteDataSource {}

void main() {
  late MockMemoRepository mockRepo;
  late MockMemoRemoteDataSource mockRemote;
  late SyncMemos useCase;

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
    // Provide a lastSyncedAt so tests use getSince() instead of getAll()
    useCase = SyncMemos(
      localRepo: mockRepo,
      remoteDatasource: mockRemote,
      lastSyncedAt: DateTime.utc(2025, 1, 1),
    );
  });

  group('SyncMemos UseCase - LWW merge', () {
    test('remote memo newer than local → local is updated', () async {
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
      final remoteMemoModel = MemoModel(
        id: 'memo-1',
        title: 'Remote',
        content: 'New content',
        createdAt: older,
        updatedAt: newer,
      );

      when(() => mockRepo.getAll()).thenAnswer((_) async => [localMemo]);
      when(() => mockRemote.getSince(any())).thenAnswer((_) async => [remoteMemoModel]);
      when(() => mockRepo.update(any())).thenAnswer((_) async {});

      // Act
      await useCase.call();

      // Assert: local should be updated with remote's newer content
      final captured = verify(() => mockRepo.update(captureAny())).captured;
      expect(captured, hasLength(1));
      final updated = captured.first as Memo;
      expect(updated.content, equals('New content'));
      expect(updated.updatedAt, equals(newer));
    });

    test('local memo newer than remote → local is NOT overwritten', () async {
      // Arrange
      final older = DateTime.utc(2026, 1, 1);
      final newer = DateTime.utc(2026, 1, 2);

      final localMemo = Memo(
        id: 'memo-1',
        title: 'Local',
        content: 'Newest local content',
        createdAt: older,
        updatedAt: newer,
      );
      final remoteMemoModel = MemoModel(
        id: 'memo-1',
        title: 'Remote',
        content: 'Older remote content',
        createdAt: older,
        updatedAt: older,
      );

      when(() => mockRepo.getAll()).thenAnswer((_) async => [localMemo]);
      when(() => mockRemote.getSince(any())).thenAnswer((_) async => [remoteMemoModel]);
      when(() => mockRepo.update(any())).thenAnswer((_) async {});

      // Act
      await useCase.call();

      // Assert: update should NOT be called (local is newer)
      verifyNever(() => mockRepo.update(any()));
    });

    test('new remote memo not in local → created locally', () async {
      // Arrange
      final now = DateTime.utc(2026, 1, 1);
      final remoteMemoModel = MemoModel(
        id: 'new-remote-memo',
        title: 'From Remote',
        content: 'Remote only',
        createdAt: now,
        updatedAt: now,
      );

      when(() => mockRepo.getAll()).thenAnswer((_) async => []);
      when(() => mockRemote.getAll()).thenAnswer((_) async => [remoteMemoModel]);
      when(() => mockRemote.getSince(any())).thenAnswer((_) async => [remoteMemoModel]);
      when(() => mockRepo.create(any())).thenAnswer((_) async {});

      // Act
      await useCase.call();

      // Assert: new memo should be created locally
      verify(() => mockRepo.create(any())).called(1);
    });
  });
}
