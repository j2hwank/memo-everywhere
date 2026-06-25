import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/memo.dart';

/// Displays a single memo as a tappable card.
///
/// Shows the [Memo.title] when present, otherwise a truncated [Memo.content]
/// preview. Triggers [onTap] for edit and [onLongPress] for delete confirmation.
class MemoCard extends StatelessWidget {
  const MemoCard({
    super.key,
    required this.memo,
    required this.onTap,
    required this.onLongPress,
  });

  final Memo memo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// Returns a human-readable relative time string for the card subtitle.
  String _relativeTime(DateTime updatedAt) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(updatedAt.toUtc());

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(updatedAt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = memo.title ?? _contentPreview(memo.content);
    final timeText = _relativeTime(memo.updatedAt);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayTitle,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                timeText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _contentPreview(String content) {
    const maxChars = 100;
    if (content.length <= maxChars) return content;
    return '${content.substring(0, maxChars)}...';
  }
}
