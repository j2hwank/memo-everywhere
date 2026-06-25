import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/presentation/pages/home_page.dart';
import 'package:memo_everywhere/presentation/state/memo_provider.dart';

class MockMemosNotifier extends AutoDisposeAsyncNotifier<List<Memo>>
    with Mock
    implements Memos {
  final List<Memo> _memos;
  MockMemosNotifier(this._memos);

  @override
  Future<List<Memo>> build() async => _memos;
}

Widget buildHomePage(List<Memo> memos) {
  return ProviderScope(
    overrides: [
      memosProvider.overrideWith(() => MockMemosNotifier(memos)),
      memoNotifierProvider.overrideWith(() => _NoOpMemoNotifier()),
    ],
    child: const MaterialApp(
      home: HomePage(),
    ),
  );
}

class _NoOpMemoNotifier extends AutoDisposeNotifier<void> implements MemoNotifier {
  @override
  void build() {}

  @override
  Future<void> create({String? title, required String content}) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> update({
    required Memo memo,
    String? title,
    required String content,
    bool clearTitle = false,
  }) async {}
}

void main() {
  final DateTime t1 = DateTime.utc(2024, 1, 10, 8, 0);
  final DateTime t2 = DateTime.utc(2024, 1, 10, 9, 0);

  group('HomePage — empty state', () {
    testWidgets('shows empty state message when no memos', (tester) async {
      await tester.pumpWidget(buildHomePage([]));
      await tester.pump();

      expect(find.text('메모가 없습니다'), findsOneWidget);
    });

    testWidgets('FAB is visible when no memos', (tester) async {
      await tester.pumpWidget(buildHomePage([]));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('HomePage — list with memos', () {
    final memos = [
      Memo(id: '1', title: 'First Memo', content: 'First content', createdAt: t1, updatedAt: t2),
      Memo(id: '2', title: 'Second Memo', content: 'Second content', createdAt: t1, updatedAt: t1),
    ];

    testWidgets('shows memo cards for each memo', (tester) async {
      await tester.pumpWidget(buildHomePage(memos));
      await tester.pump();

      expect(find.text('First Memo'), findsOneWidget);
      expect(find.text('Second Memo'), findsOneWidget);
    });

    testWidgets('FAB is present when memos exist', (tester) async {
      await tester.pumpWidget(buildHomePage(memos));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('does not show empty state when memos exist', (tester) async {
      await tester.pumpWidget(buildHomePage(memos));
      await tester.pump();

      expect(find.text('메모가 없습니다'), findsNothing);
    });
  });
}
