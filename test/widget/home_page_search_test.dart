import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/presentation/pages/home_page.dart';
import 'package:memo_everywhere/presentation/state/memo_provider.dart';
import 'widget_test_helpers.dart';

class _FakeMemosNotifier extends AutoDisposeAsyncNotifier<List<Memo>> implements Memos {
  final List<Memo> _memos;
  _FakeMemosNotifier(this._memos);
  @override
  Future<List<Memo>> build() async => _memos;
}

class _NoOpMemoNotifier extends AutoDisposeNotifier<void> implements MemoNotifier {
  @override
  void build() {}
  @override
  Future<void> create({String? title, required String content}) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> update({required Memo memo, String? title, required String content, bool clearTitle = false}) async {}
}

final DateTime t = DateTime.utc(2024, 1, 1);
final List<Memo> testMemos = [
  Memo(id: '1', title: 'Flutter 개발', content: 'Dart 언어', createdAt: t, updatedAt: t),
  Memo(id: '2', title: 'Meeting Notes', content: 'project roadmap', createdAt: t, updatedAt: t),
];

Widget buildHomePage(List<Memo> memos) {
  return ProviderScope(
    overrides: [
      ...syncProviderOverrides,
      memosProvider.overrideWith(() => _FakeMemosNotifier(memos)),
      memoNotifierProvider.overrideWith(() => _NoOpMemoNotifier()),
    ],
    child: const MaterialApp(home: HomePage()),
  );
}

void main() {
  group('HomePage — 검색 기능', () {
    testWidgets('T-008: AppBar에 검색 아이콘이 표시된다', (tester) async {
      await tester.pumpWidget(buildHomePage(testMemos));
      await tester.pump();
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('T-009: 검색 아이콘 탭 시 검색 입력바로 전환된다', (tester) async {
      await tester.pumpWidget(buildHomePage(testMemos));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('T-010: 검색어 입력 시 필터링된 메모만 표시된다', (tester) async {
      await tester.pumpWidget(buildHomePage(testMemos));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Flutter');
      await tester.pump(const Duration(milliseconds: 310));
      expect(find.text('Flutter 개발'), findsOneWidget);
      expect(find.text('Meeting Notes'), findsNothing);
    });

    testWidgets('T-011: 닫기 버튼 탭 시 전체 목록으로 복귀한다', (tester) async {
      await tester.pumpWidget(buildHomePage(testMemos));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Flutter');
      await tester.pump(const Duration(milliseconds: 310));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 310));
      expect(find.text('Flutter 개발'), findsOneWidget);
      expect(find.text('Meeting Notes'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('T-012: 매칭 없는 검색어 입력 시 "검색 결과가 없습니다" 표시', (tester) async {
      await tester.pumpWidget(buildHomePage(testMemos));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '존재하지않는키워드xyz');
      await tester.pump(const Duration(milliseconds: 310));
      expect(find.text('검색 결과가 없습니다'), findsOneWidget);
    });
  });
}
