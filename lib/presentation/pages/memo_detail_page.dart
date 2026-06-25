import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/memo.dart';
import '../../core/router/app_router.dart';

// @MX:NOTE: [AUTO] Read mode uses MarkdownBody for visual rendering (REQ-WM-002).
//           This page is READ-ONLY. Editing navigates to MemoEditorPage which
//           maintains plain-text input (REQ-WM-003). Data stored is always pure
//           text — rendering does NOT modify the stored content.

/// Read-mode detail page that renders memo content as markdown.
///
/// REQ-WM-002: Renders markdown visually in read mode.
/// REQ-WM-003: Editing stays in MemoEditorPage with plain text (no markdown editor here).
/// REQ-WM-004: Supports #/##/###, **bold**, *italic*, - lists, ``` code, > blockquote, [links](url).
class MemoDetailPage extends StatelessWidget {
  const MemoDetailPage({super.key, required this.memo});

  /// The memo to display in read mode.
  final Memo memo;

  @override
  Widget build(BuildContext context) {
    final title = memo.title ?? memo.content.split('\n').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      // @MX:WARN: [AUTO] htmlBlockSyntax is NOT enabled — raw HTML blocks in
      //           memo content are treated as plain text, preventing injection.
      // @MX:REASON: Memo content is user-supplied; allowing HTML would enable
      //             script injection in the web renderer (security constraint).
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: memo.content,
          selectable: true,
          // Secure: do not enable syntaxHighlighter or custom HTML extensions
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.editMemo(memo.id)),
        tooltip: '편집',
        child: const Icon(Icons.edit),
      ),
    );
  }
}
