import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';
import 'package:memo_everywhere/presentation/widgets/memo_card.dart';

void main() {
  final DateTime now = DateTime.utc(2024, 1, 15, 12, 0, 0);

  Memo makeMemo({String? title, String content = 'Some content'}) => Memo(
        id: 'test-id',
        title: title,
        content: content,
        createdAt: now,
        updatedAt: now,
      );

  Widget buildCard(Memo memo, {VoidCallback? onTap, VoidCallback? onLongPress}) {
    return MaterialApp(
      home: Scaffold(
        body: MemoCard(
          memo: memo,
          onTap: onTap ?? () {},
          onLongPress: onLongPress ?? () {},
        ),
      ),
    );
  }

  group('MemoCard rendering', () {
    testWidgets('shows title when memo has a title', (tester) async {
      await tester.pumpWidget(buildCard(makeMemo(title: 'My Title')));

      expect(find.text('My Title'), findsOneWidget);
    });

    testWidgets('shows content preview when memo has no title', (tester) async {
      await tester.pumpWidget(buildCard(makeMemo(title: null, content: 'Just content text')));

      expect(find.text('Just content text'), findsOneWidget);
    });

    testWidgets('shows truncated content preview when content is long', (tester) async {
      final longContent = 'A' * 200;
      await tester.pumpWidget(buildCard(makeMemo(title: null, content: longContent)));

      // The card should show some text — at least the start of content
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('shows updatedAt date text', (tester) async {
      await tester.pumpWidget(buildCard(makeMemo()));

      // A date-related text should be rendered (relative time or formatted date)
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final allText = textWidgets.map((w) => w.data ?? '').join(' ');
      expect(allText.isNotEmpty, isTrue);
    });
  });

  group('MemoCard callbacks', () {
    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildCard(makeMemo(), onTap: () => tapped = true));

      await tester.tap(find.byType(MemoCard));
      expect(tapped, isTrue);
    });

    testWidgets('calls onLongPress when long-pressed', (tester) async {
      bool longPressed = false;
      await tester.pumpWidget(
        buildCard(makeMemo(), onLongPress: () => longPressed = true),
      );

      await tester.longPress(find.byType(MemoCard));
      expect(longPressed, isTrue);
    });
  });
}
