import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/presentation/pages/memo_detail_page.dart';
import 'package:memo_everywhere/presentation/state/memo_provider.dart';

// ---------------------------------------------------------------------------
// Fake providers
// ---------------------------------------------------------------------------

class _FakeMemosNotifier extends AutoDisposeAsyncNotifier<List<Memo>>
    implements Memos {
  final List<Memo> _memos;
  _FakeMemosNotifier(this._memos);

  @override
  Future<List<Memo>> build() async => _memos;
}

class _NoOpMemoNotifier extends AutoDisposeNotifier<void>
    implements MemoNotifier {
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

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Memo _testMemo({String content = '# Hello\n\n**bold** *italic*'}) {
  final now = DateTime.utc(2024, 1, 1);
  return Memo(
    id: 'test-id-001',
    title: 'Test Memo',
    content: content,
    createdAt: now,
    updatedAt: now,
  );
}

Widget buildDetailPage(Memo memo) {
  return ProviderScope(
    overrides: [
      memosProvider.overrideWith(() => _FakeMemosNotifier([memo])),
      memoNotifierProvider.overrideWith(() => _NoOpMemoNotifier()),
    ],
    child: MaterialApp(
      home: MemoDetailPage(memo: memo),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests (AC-2, AC-3, AC-4)
// ---------------------------------------------------------------------------

void main() {
  group('MemoDetailPage — read mode (AC-2)', () {
    testWidgets('shows MarkdownBody in read mode', (tester) async {
      final memo = _testMemo();
      await tester.pumpWidget(buildDetailPage(memo));
      await tester.pump();

      // AC-2: read mode renders markdown via MarkdownBody
      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('MarkdownBody receives memo content as data (AC-4)',
        (tester) async {
      const markdownContent =
          '# Header\n\n**bold** *italic*\n\n- item\n\n> quote\n\n`code`\n\n[link](https://example.com)';
      final memo = _testMemo(content: markdownContent);
      await tester.pumpWidget(buildDetailPage(memo));
      await tester.pump();

      final markdownBody =
          tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      // AC-4: markdown body receives the raw content string for rendering
      expect(markdownBody.data, equals(markdownContent));
    });

    testWidgets('does NOT show TextField in read mode', (tester) async {
      final memo = _testMemo();
      await tester.pumpWidget(buildDetailPage(memo));
      await tester.pump();

      // Read mode should not have a TextField
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows memo title in AppBar', (tester) async {
      final memo = _testMemo();
      await tester.pumpWidget(buildDetailPage(memo));
      await tester.pump();

      expect(find.text('Test Memo'), findsOneWidget);
    });
  });

  group('MemoDetailPage — navigation to edit mode (AC-3)', () {
    testWidgets('has edit button/FAB to navigate to editor', (tester) async {
      final memo = _testMemo();
      await tester.pumpWidget(buildDetailPage(memo));
      await tester.pump();

      // AC-3: There should be an edit action (FAB or button with edit icon)
      expect(
        find.byIcon(Icons.edit),
        findsOneWidget,
      );
    });
  });
}
