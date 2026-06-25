import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../domain/entities/memo.dart';
import '../state/memo_provider.dart';
import '../widgets/memo_card.dart';

/// Main screen: lists all memos (updatedAt DESC) with a FAB to create new ones.
///
/// REQ-MEMO-001: FAB tapped → navigate to MemoEditorPage create mode.
/// REQ-MEMO-004: displays all memos updatedAt DESC.
/// REQ-MEMO-005: shows empty state message when no memos exist.
/// REQ-MEMO-008: long-press → confirm dialog → delete.
/// REQ-SEARCH-001: AppBar search bar filters memos by title/content.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    // @MX:NOTE: [AUTO] 300ms debounce prevents filteredMemosProvider rebuild on every keystroke.
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = query;
    });
  }

  void _startSearch() => setState(() => _isSearching = true);

  void _stopSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    setState(() => _isSearching = false);
  }

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
  Widget build(BuildContext context) {
    final memosAsync = ref.watch(filteredMemosProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '검색...',
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text('메모'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_voice',
            onPressed: () => context.push(AppRoutes.voice),
            tooltip: '음성 메모',
            child: const Icon(Icons.mic),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'fab_new',
            onPressed: () => context.push(AppRoutes.newMemo),
            tooltip: '새 메모',
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: memosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (memos) {
          if (memos.isEmpty) {
            final query = ref.read(searchQueryProvider);
            return Center(
              child: Text(
                query.trim().isNotEmpty ? '검색 결과가 없습니다' : '메모가 없습니다',
              ),
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
