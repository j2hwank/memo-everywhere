import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/domain/repositories/memo_repository.dart';
import 'package:memo_everywhere/domain/usecases/create_memo.dart';

class MockMemoRepository extends Mock implements MemoRepository {}

class MockUuid extends Mock implements Uuid {}

void main() {
  late MockMemoRepository mockRepository;
  late MockUuid mockUuid;
  late CreateMemo usecase;

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
    mockUuid = MockUuid();
    usecase = CreateMemo(mockRepository, uuid: mockUuid);
    when(() => mockRepository.create(any())).thenAnswer((_) async {});
    when(() => mockUuid.v4()).thenReturn('fixed-uuid-001');
  });

  group('CreateMemo usecase', () {
    test('calls repository.create with a memo having a uuid v4 id', () async {
      final result = await usecase(content: 'Hello world');

      expect(result.id, equals('fixed-uuid-001'));
      verify(() => mockRepository.create(any())).called(1);
    });

    test('sets title when provided', () async {
      final result = await usecase(title: 'My Title', content: 'Body text');

      expect(result.title, equals('My Title'));
      expect(result.content, equals('Body text'));
    });

    test('title is null when not provided', () async {
      final result = await usecase(content: 'Body text');

      expect(result.title, isNull);
    });

    test('createdAt and updatedAt are set to UTC now (approximately)', () async {
      final before = DateTime.now().toUtc();
      final result = await usecase(content: 'Some content');
      final after = DateTime.now().toUtc();

      expect(result.createdAt.isAfter(before) || result.createdAt.isAtSameMomentAs(before), isTrue);
      expect(result.createdAt.isBefore(after) || result.createdAt.isAtSameMomentAs(after), isTrue);
      expect(result.updatedAt, equals(result.createdAt));
      expect(result.createdAt.isUtc, isTrue);
    });

    test('returns the created memo', () async {
      final result = await usecase(title: 'T', content: 'C');

      expect(result, isA<Memo>());
      expect(result.id, equals('fixed-uuid-001'));
      expect(result.title, equals('T'));
      expect(result.content, equals('C'));
    });
  });
}
