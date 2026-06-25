import '../entities/memo.dart';

// @MX:ANCHOR: [AUTO] filteredMemosProvider depends on this for all search filtering.
// @MX:REASON: Changing the matching contract (case sensitivity, null handling,
//             substring vs prefix) propagates immediately to UI search results.
class SearchMemos {
  const SearchMemos();

  List<Memo> call(String query, List<Memo> memos) {
    if (query.trim().isEmpty) return memos;
    final q = query.toLowerCase();
    return memos.where((m) {
      // @MX:NOTE: [AUTO] title is nullable; avoid NPE by short-circuiting with ?.
      final titleMatch = m.title?.toLowerCase().contains(q) ?? false;
      return titleMatch || m.content.toLowerCase().contains(q);
    }).toList();
  }
}
