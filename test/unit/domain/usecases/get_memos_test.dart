import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/domain/repositories/memo_repository.dart';
import 'package:memo_everywhere/domain/usecases/get_memos.dart';

class MockMemoRepository extends Mock implements MemoRepository {}

void main() {
  late MockMemoRepository mockRepository;
  late GetMemos usecase;

  final DateTime t1 = DateTime.utc(2024, 1, 15, 10, 0);
  final DateTime t2 = DateTime.utc(2024, 1, 15, 11, 0);
  final DateTime t3 = DateTime.utc(2024, 1, 15, 12, 0);

  setUp(() {
    mockRepository = MockMemoRepository();
    usecase = GetMemos(mockRepository);
  });

  group('GetMemos usecase', () {
    test('returns empty list when no memos', () async {
      when(() => mockRepository.getAll()).thenAnswer((_) async => []);

      final result = await usecase();

      expect(result, isEmpty);
    });

    test('delegates to repository and returns the result', () async {
      final memos = [
        Memo(id: '1', title: 'A', content: 'A body', createdAt: t1, updatedAt: t3),
        Memo(id: '2', title: 'B', content: 'B body', createdAt: t1, updatedAt: t2),
        Memo(id: '3', title: 'C', content: 'C body', createdAt: t1, updatedAt: t1),
      ];
      when(() => mockRepository.getAll()).thenAnswer((_) async => memos);

      final result = await usecase();

      expect(result, equals(memos));
      verify(() => mockRepository.getAll()).called(1);
    });

    test('result is already sorted updatedAt DESC (as returned by repository)', () async {
      // The sort responsibility lives in the repository impl; the usecase trusts it.
      final sorted = [
        Memo(id: '1', title: null, content: 'Newest', createdAt: t1, updatedAt: t3),
        Memo(id: '2', title: null, content: 'Middle', createdAt: t1, updatedAt: t2),
        Memo(id: '3', title: null, content: 'Oldest', createdAt: t1, updatedAt: t1),
      ];
      when(() => mockRepository.getAll()).thenAnswer((_) async => sorted);

      final result = await usecase();

      expect(result[0].updatedAt, equals(t3));
      expect(result[1].updatedAt, equals(t2));
      expect(result[2].updatedAt, equals(t1));
    });
  });
}
