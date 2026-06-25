import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/domain/repositories/memo_repository.dart';
import 'package:memo_everywhere/domain/usecases/update_memo.dart';

class MockMemoRepository extends Mock implements MemoRepository {}

void main() {
  late MockMemoRepository mockRepository;
  late UpdateMemo usecase;

  final DateTime created = DateTime.utc(2024, 1, 10, 8, 0);
  final DateTime originalUpdated = DateTime.utc(2024, 1, 10, 9, 0);

  final Memo originalMemo = Memo(
    id: 'memo-id-1',
    title: 'Original Title',
    content: 'Original content',
    createdAt: created,
    updatedAt: originalUpdated,
  );

  setUpAll(() {
    registerFallbackValue(Memo(
      id: 'fallback',
      title: null,
      content: 'fallback',
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
    ));
  });

  setUp(() {
    mockRepository = MockMemoRepository();
    usecase = UpdateMemo(mockRepository);
    when(() => mockRepository.update(any())).thenAnswer((_) async {});
  });

  group('UpdateMemo usecase', () {
    test('preserves createdAt from the original memo', () async {
      final result = await usecase(
        memo: originalMemo,
        content: 'Updated content',
      );

      expect(result.createdAt, equals(created));
    });

    test('updates updatedAt to a new UTC timestamp', () async {
      final before = DateTime.now().toUtc();
      final result = await usecase(
        memo: originalMemo,
        content: 'Updated content',
      );
      final after = DateTime.now().toUtc();

      expect(result.updatedAt.isAfter(originalUpdated), isTrue);
      expect(result.updatedAt.isAfter(before) || result.updatedAt.isAtSameMomentAs(before), isTrue);
      expect(result.updatedAt.isBefore(after) || result.updatedAt.isAtSameMomentAs(after), isTrue);
      expect(result.updatedAt.isUtc, isTrue);
    });

    test('updates content', () async {
      final result = await usecase(
        memo: originalMemo,
        content: 'New content text',
      );

      expect(result.content, equals('New content text'));
    });

    test('updates title when provided', () async {
      final result = await usecase(
        memo: originalMemo,
        title: 'New Title',
        content: 'New content',
      );

      expect(result.title, equals('New Title'));
    });

    test('clears title when clearTitle is true', () async {
      final result = await usecase(
        memo: originalMemo,
        content: 'New content',
        clearTitle: true,
      );

      expect(result.title, isNull);
    });

    test('preserves original title when title is not supplied', () async {
      final result = await usecase(
        memo: originalMemo,
        content: 'New content',
      );

      expect(result.title, equals('Original Title'));
    });

    test('calls repository.update once', () async {
      await usecase(memo: originalMemo, content: 'Content');

      verify(() => mockRepository.update(any())).called(1);
    });

    test('returns the updated memo', () async {
      final result = await usecase(
        memo: originalMemo,
        content: 'Updated',
      );

      expect(result.id, equals(originalMemo.id));
    });
  });
}
