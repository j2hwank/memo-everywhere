import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/domain/repositories/memo_repository.dart';
import 'package:memo_everywhere/domain/usecases/delete_memo.dart';

class MockMemoRepository extends Mock implements MemoRepository {}

void main() {
  late MockMemoRepository mockRepository;
  late DeleteMemo usecase;

  setUp(() {
    mockRepository = MockMemoRepository();
    usecase = DeleteMemo(mockRepository);
    when(() => mockRepository.delete(any())).thenAnswer((_) async {});
  });

  group('DeleteMemo usecase', () {
    test('calls repository.delete with the given id', () async {
      await usecase('memo-to-delete-id');

      verify(() => mockRepository.delete('memo-to-delete-id')).called(1);
    });

    test('does not call repository.delete with a different id', () async {
      await usecase('correct-id');

      verifyNever(() => mockRepository.delete('wrong-id'));
    });

    test('propagates exceptions from the repository', () async {
      when(() => mockRepository.delete(any()))
          .thenThrow(Exception('Hive error'));

      expect(
        () => usecase('some-id'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
