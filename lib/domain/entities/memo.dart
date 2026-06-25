/// Immutable value object representing a single memo in the domain layer.
///
/// No external dependencies — pure Dart.
class Memo {
  const Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// Optional title. When null the UI shows a content preview instead.
  final String? title;

  /// Main text body. Must not be empty when persisted (enforced at the UI layer).
  final String content;

  /// UTC timestamp when this memo was first created; never changed on update.
  final DateTime createdAt;

  /// UTC timestamp of the most recent save; used for DESC sort on the list.
  final DateTime updatedAt;

  /// Returns a new [Memo] with the given fields replaced.
  ///
  /// Use [clearTitle] = true to explicitly set [title] to null.
  Memo copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearTitle = false,
  }) {
    return Memo(
      id: id ?? this.id,
      title: clearTitle ? null : (title ?? this.title),
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Memo &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(id, title, content, createdAt, updatedAt);

  @override
  String toString() =>
      'Memo(id: $id, title: $title, content: $content, '
      'createdAt: $createdAt, updatedAt: $updatedAt)';
}
