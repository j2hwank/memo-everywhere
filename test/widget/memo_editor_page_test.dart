import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/presentation/pages/memo_editor_page.dart';
import 'package:memo_everywhere/presentation/state/memo_provider.dart';

class _NoOpMemoNotifier extends AutoDisposeNotifier<void> implements MemoNotifier {
  bool createCalled = false;
  bool updateCalled = false;

  @override
  void build() {}

  @override
  Future<void> create({String? title, required String content}) async {
    createCalled = true;
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> update({
    required Memo memo,
    String? title,
    required String content,
    bool clearTitle = false,
  }) async {
    updateCalled = true;
  }
}

Widget buildEditor({
  Memo? memo,
  required _NoOpMemoNotifier notifier,
  List<Memo> memos = const [],
}) {
  return ProviderScope(
    overrides: [
      memoNotifierProvider.overrideWith(() => notifier),
      memosProvider.overrideWith(() => _FakeMemosNotifier(memos)),
    ],
    child: MaterialApp(
      home: MemoEditorPage(memo: memo),
    ),
  );
}

class _FakeMemosNotifier extends AutoDisposeAsyncNotifier<List<Memo>> implements Memos {
  final List<Memo> _memos;
  _FakeMemosNotifier(this._memos);

  @override
  Future<List<Memo>> build() async => _memos;
}

void main() {
  final DateTime now = DateTime.utc(2024, 1, 15, 10, 0);

  final existingMemo = Memo(
    id: 'existing-id',
    title: 'Existing Title',
    content: 'Existing content body',
    createdAt: now,
    updatedAt: now,
  );

  group('MemoEditorPage — create mode', () {
    testWidgets('shows empty title and content fields in create mode', (tester) async {
      final notifier = _NoOpMemoNotifier();
      await tester.pumpWidget(buildEditor(notifier: notifier));

      final titleFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(titleFields.isNotEmpty, isTrue);
    });

    testWidgets('shows validation error and does NOT call create when content is empty', (tester) async {
      final notifier = _NoOpMemoNotifier();
      await tester.pumpWidget(buildEditor(notifier: notifier));
      await tester.pump();

      // Tap Save without entering content
      await tester.tap(find.text('저장'));
      await tester.pump();

      expect(notifier.createCalled, isFalse);
      expect(find.text('내용을 입력해 주세요'), findsOneWidget);
    });

    testWidgets('calls create when content is non-empty', (tester) async {
      final notifier = _NoOpMemoNotifier();
      await tester.pumpWidget(buildEditor(notifier: notifier));
      await tester.pump();

      // Find content field (second TextField) and enter text
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.last, 'New memo content');
      await tester.pump();

      await tester.tap(find.text('저장'));
      await tester.pump();

      expect(notifier.createCalled, isTrue);
    });
  });

  group('MemoEditorPage — edit mode', () {
    testWidgets('pre-fills title and content in edit mode', (tester) async {
      final notifier = _NoOpMemoNotifier();
      await tester.pumpWidget(buildEditor(memo: existingMemo, notifier: notifier));
      await tester.pump();

      expect(find.text('Existing Title'), findsOneWidget);
      expect(find.text('Existing content body'), findsOneWidget);
    });

    testWidgets('calls update when saving in edit mode with non-empty content', (tester) async {
      final notifier = _NoOpMemoNotifier();
      await tester.pumpWidget(buildEditor(memo: existingMemo, notifier: notifier));
      await tester.pump();

      // Clear and re-enter content
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.last, 'Updated content');
      await tester.pump();

      await tester.tap(find.text('저장'));
      await tester.pump();

      expect(notifier.updateCalled, isTrue);
      expect(notifier.createCalled, isFalse);
    });

    testWidgets('shows validation error when clearing content in edit mode', (tester) async {
      final notifier = _NoOpMemoNotifier();
      await tester.pumpWidget(buildEditor(memo: existingMemo, notifier: notifier));
      await tester.pump();

      // Clear content field
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.last, '');
      await tester.pump();

      await tester.tap(find.text('저장'));
      await tester.pump();

      expect(notifier.updateCalled, isFalse);
      expect(find.text('내용을 입력해 주세요'), findsOneWidget);
    });
  });
}
