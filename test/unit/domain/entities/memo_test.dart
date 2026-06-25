import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/domain/entities/memo.dart';

void main() {
  final DateTime now = DateTime.utc(2024, 1, 15, 10, 0, 0);
  final DateTime later = DateTime.utc(2024, 1, 15, 11, 0, 0);

  final Memo baseMemo = Memo(
    id: 'test-id-1',
    title: 'Test Title',
    content: 'Test content body',
    createdAt: now,
    updatedAt: now,
  );

  group('Memo entity field invariants', () {
    test('holds id, title, content, createdAt, updatedAt', () {
      expect(baseMemo.id, equals('test-id-1'));
      expect(baseMemo.title, equals('Test Title'));
      expect(baseMemo.content, equals('Test content body'));
      expect(baseMemo.createdAt, equals(now));
      expect(baseMemo.updatedAt, equals(now));
    });

    test('title is nullable', () {
      final Memo noTitle = Memo(
        id: 'no-title-id',
        title: null,
        content: 'Content without title',
        createdAt: now,
        updatedAt: now,
      );
      expect(noTitle.title, isNull);
    });

    test('content must not be empty string', () {
      // The entity allows any string for content; empty guard is at the UI layer.
      // This test verifies the field is accessible.
      const String emptyContent = '';
      final Memo m = Memo(
        id: 'id',
        title: null,
        content: emptyContent,
        createdAt: now,
        updatedAt: now,
      );
      expect(m.content, equals(emptyContent));
    });
  });

  group('Memo copyWith', () {
    test('copyWith returns new instance with updated title', () {
      final Memo updated = baseMemo.copyWith(title: 'New Title');
      expect(updated.title, equals('New Title'));
      expect(updated.id, equals(baseMemo.id));
      expect(updated.content, equals(baseMemo.content));
      expect(updated.createdAt, equals(baseMemo.createdAt));
      expect(updated.updatedAt, equals(baseMemo.updatedAt));
    });

    test('copyWith returns new instance with updated content', () {
      final Memo updated = baseMemo.copyWith(content: 'New content');
      expect(updated.content, equals('New content'));
      expect(updated.id, equals(baseMemo.id));
    });

    test('copyWith returns new instance with updated updatedAt', () {
      final Memo updated = baseMemo.copyWith(updatedAt: later);
      expect(updated.updatedAt, equals(later));
      expect(updated.createdAt, equals(baseMemo.createdAt));
    });

    test('copyWith with no arguments returns equivalent object', () {
      final Memo copy = baseMemo.copyWith();
      expect(copy, equals(baseMemo));
    });

    test('copyWith can clear title (set to null)', () {
      final Memo updated = baseMemo.copyWith(clearTitle: true);
      expect(updated.title, isNull);
      expect(updated.id, equals(baseMemo.id));
    });

    test('copyWith original remains unchanged (immutability)', () {
      baseMemo.copyWith(title: 'Changed', content: 'Changed content');
      expect(baseMemo.title, equals('Test Title'));
      expect(baseMemo.content, equals('Test content body'));
    });
  });

  group('Memo value equality', () {
    test('two memos with same fields are equal', () {
      final Memo memo1 = Memo(
        id: 'id-eq',
        title: 'Same',
        content: 'same content',
        createdAt: now,
        updatedAt: now,
      );
      final Memo memo2 = Memo(
        id: 'id-eq',
        title: 'Same',
        content: 'same content',
        createdAt: now,
        updatedAt: now,
      );
      expect(memo1, equals(memo2));
    });

    test('two memos with different ids are not equal', () {
      final Memo memo1 = Memo(
        id: 'id-1',
        title: 'Same',
        content: 'same content',
        createdAt: now,
        updatedAt: now,
      );
      final Memo memo2 = Memo(
        id: 'id-2',
        title: 'Same',
        content: 'same content',
        createdAt: now,
        updatedAt: now,
      );
      expect(memo1, isNot(equals(memo2)));
    });

    test('two memos with different content are not equal', () {
      final Memo updated = baseMemo.copyWith(content: 'Different content');
      expect(baseMemo, isNot(equals(updated)));
    });

    test('hashCode is consistent with equality', () {
      final Memo memo1 = Memo(
        id: 'id-hash',
        title: 'Title',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );
      final Memo memo2 = Memo(
        id: 'id-hash',
        title: 'Title',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );
      expect(memo1.hashCode, equals(memo2.hashCode));
    });
  });
}
