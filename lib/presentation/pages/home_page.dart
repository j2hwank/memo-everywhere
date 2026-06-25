import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/memo.dart';
import '../state/memo_provider.dart';
import '../widgets/memo_card.dart';

/// Main screen: lists all memos (updatedAt DESC) with a FAB to create new ones.
///
/// REQ-MEMO-001: FAB tapped → navigate to MemoEditorPage create mode.
/// REQ-MEMO-004: displays all memos updatedAt DESC.
/// REQ-MEMO-005: shows empty state message when no memos exist.
/// REQ-MEMO-008: long-press → confirm dialog → delete.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Memo memo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메모 삭제'),
        content: const Text('이 메모를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(memoNotifierProvider.notifier).delete(memo.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(memosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Memo Everywhere')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/memo/new'),
        child: const Icon(Icons.add),
      ),
      body: memosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (memos) {
          if (memos.isEmpty) {
            return const Center(
              child: Text('메모가 없습니다'),
            );
          }
          return ListView.builder(
            itemCount: memos.length,
            itemBuilder: (context, index) {
              final memo = memos[index];
              return MemoCard(
                memo: memo,
                onTap: () => context.push('/memo/${memo.id}'),
                onLongPress: () => _confirmDelete(context, ref, memo),
              );
            },
          );
        },
      ),
    );
  }
}
