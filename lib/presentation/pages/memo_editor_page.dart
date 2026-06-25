import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/memo.dart';
import '../state/memo_provider.dart';

/// Text memo editor — create and edit modes.
///
/// REQ-MEMO-002: Save with non-empty content → persist + navigate back.
/// REQ-MEMO-003: Save with empty content → validation error, do NOT save.
/// REQ-MEMO-006: Edit mode pre-fills title and content.
/// REQ-MEMO-007: Save in edit mode → update, new updatedAt, preserve createdAt.
class MemoEditorPage extends ConsumerStatefulWidget {
  const MemoEditorPage({super.key, this.memo});

  /// When null the page is in create mode; otherwise edit mode.
  final Memo? memo;

  @override
  ConsumerState<MemoEditorPage> createState() => _MemoEditorPageState();
}

class _MemoEditorPageState extends ConsumerState<MemoEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String? _contentError;

  bool get _isEditMode => widget.memo != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.memo?.title ?? '');
    _contentController =
        TextEditingController(text: widget.memo?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _contentError = '내용을 입력해 주세요');
      return;
    }
    setState(() => _contentError = null);

    final title = _titleController.text.trim();
    final notifier = ref.read(memoNotifierProvider.notifier);

    if (_isEditMode) {
      await notifier.update(
        memo: widget.memo!,
        title: title.isEmpty ? null : title,
        content: content,
        clearTitle: title.isEmpty,
      );
    } else {
      await notifier.create(
        title: title.isEmpty ? null : title,
        content: content,
      );
    }

    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '메모 편집' : '새 메모'),
        actions: [
          TextButton(
            onPressed: _onSave,
            child: const Text('저장'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // @MX:NOTE: macOS Korean IME workaround — TextInputAction.next prematurely
            // commits Hangul composition on macOS. Use newline on macOS to keep IME
            // composing across jamo sequences (ㅎ→하→한). scribbleEnabled: false
            // reduces interference from macOS Scribble/Handwriting input path.
            // Root cause partially resides in FlutterTextInputPlugin.mm (engine-level);
            // this app-level fix reduces visible cursor-jump symptoms.
            // @MX:REASON: macOS SPM integration detected (XCLocalSwiftPackageReference),
            // compounding text-input plugin interference during IME composition.
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '제목 (선택)',
                border: InputBorder.none,
              ),
              style: Theme.of(context).textTheme.titleLarge,
              // On macOS, TextInputAction.next commits Korean IME composition early.
              textInputAction: Platform.isMacOS
                  ? TextInputAction.newline
                  : TextInputAction.next,
              stylusHandwritingEnabled: !Platform.isMacOS,
              enableIMEPersonalizedLearning: false,
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: '내용을 입력해 주세요...',
                  border: InputBorder.none,
                  errorText: _contentError,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                stylusHandwritingEnabled: !Platform.isMacOS,
                enableIMEPersonalizedLearning: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
