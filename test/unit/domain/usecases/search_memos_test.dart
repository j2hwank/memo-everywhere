import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/domain/usecases/search_memos.dart';

void main() {
  late SearchMemos usecase;
  final DateTime t = DateTime.utc(2024, 1, 1);

  setUp(() => usecase = const SearchMemos());

  final memos = [
    Memo(id: '1', title: 'Flutter 개발', content: 'Dart 언어로 앱 개발', createdAt: t, updatedAt: t),
    Memo(id: '2', title: 'Meeting Notes', content: 'Discuss project roadmap', createdAt: t, updatedAt: t),
    Memo(id: '3', title: null, content: '제목 없는 메모 내용', createdAt: t, updatedAt: t),
    Memo(id: '4', title: '회의 로그 정리', content: 'Q4 results', createdAt: t, updatedAt: t),
  ];

  group('SearchMemos usecase', () {
    test('T-001: 빈 쿼리는 전체 메모를 반환한다', () {
      expect(usecase('', memos), equals(memos));
      expect(usecase('   ', memos), equals(memos));
    });

    test('T-002: 제목 키워드로 메모를 찾는다', () {
      final result = usecase('Flutter', memos);
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('T-003: 내용 키워드로 메모를 찾는다', () {
      final result = usecase('roadmap', memos);
      expect(result.length, 1);
      expect(result.first.id, '2');
    });

    test('T-004: 대소문자를 무시하고 검색한다', () {
      expect(usecase('flutter', memos).length, 1);
      expect(usecase('FLUTTER', memos).length, 1);
      expect(usecase('Flutter', memos).length, 1);
    });

    test('T-005: title이 null인 메모는 content로 매칭한다', () {
      final result = usecase('제목 없는', memos);
      expect(result.length, 1);
      expect(result.first.id, '3');
    });

    test('T-006: 일치하는 메모가 없으면 빈 리스트를 반환한다', () {
      expect(usecase('존재하지않는키워드xyz', memos), isEmpty);
    });

    test('T-007: 부분 문자열로 매칭한다', () {
      final result = usecase('로그', memos);
      expect(result.length, 1);
      expect(result.first.id, '4');
    });
  });
}
