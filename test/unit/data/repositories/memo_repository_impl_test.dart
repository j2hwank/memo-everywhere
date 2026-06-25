import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/data/datasources/local/memo_local_datasource.dart';
import 'package:memo_everywhere/data/models/memo_model.dart';
import 'package:memo_everywhere/data/repositories/memo_repository_impl.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';

class MockMemoLocalDataSource extends Mock implements MemoLocalDataSource {}

void main() {
  late MockMemoLocalDataSource mockDataSource;
  late MemoRepositoryImpl repository;

  final DateTime t1 = DateTime.utc(2024, 1, 10, 8, 0);
  final DateTime t2 = DateTime.utc(2024, 1, 10, 9, 0);
  final DateTime t3 = DateTime.utc(2024, 1, 10, 10, 0);

  MemoModel makeModel({
    required String id,
    String? title,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) =>
      MemoModel(
        id: id,
        title: title,
        content: content,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  setUp(() {
    mockDataSource = MockMemoLocalDataSource();
    repository = MemoRepositoryImpl(mockDataSource);
    registerFallbackValue(makeModel(
      id: 'fallback',
      content: 'fallback',
      createdAt: t1,
      updatedAt: t1,
    ));
  });

  group('MemoRepositoryImpl.getAll', () {
    test('returns empty list when datasource has no models', () async {
      when(() => mockDataSource.getAll()).thenAnswer((_) async => []);

      final result = await repository.getAll();

      expect(result, isEmpty);
    });

    test('converts MemoModel list to Memo entity list', () async {
      final models = [
        makeModel(id: '1', title: 'A', content: 'Body A', createdAt: t1, updatedAt: t3),
      ];
      when(() => mockDataSource.getAll()).thenAnswer((_) async => models);

      final result = await repository.getAll();

      expect(result.length, equals(1));
      expect(result.first, isA<Memo>());
      expect(result.first.id, equals('1'));
      expect(result.first.title, equals('A'));
      expect(result.first.content, equals('Body A'));
    });

    test('sorts result by updatedAt DESC', () async {
      final models = [
        makeModel(id: '2', title: 'B', content: 'B', createdAt: t1, updatedAt: t2),
        makeModel(id: '3', title: 'C', content: 'C', createdAt: t1, updatedAt: t1),
        makeModel(id: '1', title: 'A', content: 'A', createdAt: t1, updatedAt: t3),
      ];
      when(() => mockDataSource.getAll()).thenAnswer((_) async => models);

      final result = await repository.getAll();

      expect(result[0].id, equals('1')); // t3 is newest
      expect(result[1].id, equals('2')); // t2
      expect(result[2].id, equals('3')); // t1 is oldest
    });
  });

  group('MemoRepositoryImpl.create', () {
    test('converts Memo to MemoModel and calls datasource.create', () async {
      when(() => mockDataSource.create(any())).thenAnswer((_) async {});

      final memo = Memo(
        id: 'new-id',
        title: 'New',
        content: 'New content',
        createdAt: t1,
        updatedAt: t1,
      );
      await repository.create(memo);

      final captured = verify(() => mockDataSource.create(captureAny())).captured;
      final model = captured.first as MemoModel;
      expect(model.id, equals('new-id'));
      expect(model.title, equals('New'));
      expect(model.content, equals('New content'));
    });
  });

  group('MemoRepositoryImpl.update', () {
    test('converts Memo to MemoModel and calls datasource.update', () async {
      when(() => mockDataSource.update(any())).thenAnswer((_) async {});

      final memo = Memo(
        id: 'upd-id',
        title: 'Updated',
        content: 'Updated content',
        createdAt: t1,
        updatedAt: t3,
      );
      await repository.update(memo);

      final captured = verify(() => mockDataSource.update(captureAny())).captured;
      final model = captured.first as MemoModel;
      expect(model.id, equals('upd-id'));
      expect(model.updatedAt, equals(t3));
    });
  });

  group('MemoRepositoryImpl.delete', () {
    test('calls datasource.delete with the given id', () async {
      when(() => mockDataSource.delete(any())).thenAnswer((_) async {});

      await repository.delete('del-id');

      verify(() => mockDataSource.delete('del-id')).called(1);
    });
  });

  group('Entity↔Model conversion round-trip', () {
    test('Memo → MemoModel → Memo preserves all fields', () async {
      final original = Memo(
        id: 'round-trip',
        title: 'Title',
        content: 'Content',
        createdAt: t1,
        updatedAt: t2,
      );
      when(() => mockDataSource.getAll()).thenAnswer(
        (_) async => [MemoModel.fromMemo(original)],
      );

      final result = await repository.getAll();

      expect(result.first, equals(original));
    });

    test('Memo without title round-trips correctly', () async {
      final original = Memo(
        id: 'no-title',
        title: null,
        content: 'Content only',
        createdAt: t1,
        updatedAt: t2,
      );
      when(() => mockDataSource.getAll()).thenAnswer(
        (_) async => [MemoModel.fromMemo(original)],
      );

      final result = await repository.getAll();

      expect(result.first.title, isNull);
    });
  });
}
