import 'package:hive/hive.dart';
import '../../../domain/entities/memo.dart';
import 'pending_op_store.dart';

// @MX:NOTE: [AUTO] Serialization keys used in the Hive map representation.
// Do NOT rename these constants — doing so would make existing stored ops
// unreadable after an app update.
const _kType = 'type';
const _kTypeSave = 'save';
const _kTypeDelete = 'delete';
const _kId = 'id';
const _kTitle = 'title';
const _kContent = 'content';
const _kCreatedAt = 'createdAt';
const _kUpdatedAt = 'updatedAt';

// @MX:ANCHOR: [AUTO] HivePendingOpStore — Hive-backed durable offline queue
// @MX:REASON: Production implementation of PendingOpStore; opened via
//             pendingOpStoreProvider; fan_in >= 1 from syncServiceProvider.
/// Hive-backed [PendingOpStore].
///
/// Each pending op is stored as a `Map<String, dynamic>` entry in a
/// `Box<Map>`. The map contains a `type` discriminator (`'save'` or
/// `'delete'`) plus the fields needed for replay.
///
/// Keys are stable strings ([_kType] etc.) — renaming them is a breaking
/// change that corrupts persisted data in the field.
class HivePendingOpStore implements PendingOpStore {
  // @MX:NOTE: [AUTO] Box<Map> avoids registering a custom HiveAdapter for
  // each op type. Hive natively stores Map<dynamic, dynamic>; entries are
  // accessed by sequential integer keys (0, 1, 2, …) assigned by [addAll].
  const HivePendingOpStore(this._box);

  final Box<Map> _box;

  @override
  Future<List<PendingOpEntry>> loadAll() async {
    final entries = <PendingOpEntry>[];
    // Hive Box keys are insertion-order integers when using add()/addAll();
    // toMap() returns them sorted by key, preserving FIFO order.
    for (final raw in _box.values) {
      final entry = _deserialize(raw);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  @override
  Future<void> append(PendingOpEntry op) async {
    await _box.add(_serialize(op));
  }

  @override
  Future<void> replaceAll(List<PendingOpEntry> ops) async {
    await _box.clear();
    if (ops.isNotEmpty) {
      await _box.addAll(ops.map(_serialize).toList());
    }
  }

  // ── serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> _serialize(PendingOpEntry op) {
    return switch (op) {
      PendingSaveOp(:final memo) => {
          _kType: _kTypeSave,
          _kId: memo.id,
          _kTitle: memo.title,
          _kContent: memo.content,
          _kCreatedAt: memo.createdAt.toIso8601String(),
          _kUpdatedAt: memo.updatedAt.toIso8601String(),
        },
      PendingDeleteOp(:final id) => {
          _kType: _kTypeDelete,
          _kId: id,
        },
    };
  }

  PendingOpEntry? _deserialize(Map raw) {
    final type = raw[_kType] as String?;
    switch (type) {
      case _kTypeSave:
        final memo = Memo(
          id: raw[_kId] as String,
          title: raw[_kTitle] as String?,
          content: raw[_kContent] as String,
          createdAt: DateTime.parse(raw[_kCreatedAt] as String),
          updatedAt: DateTime.parse(raw[_kUpdatedAt] as String),
        );
        return PendingSaveOp(memo);
      case _kTypeDelete:
        return PendingDeleteOp(raw[_kId] as String);
      default:
        // Unknown type — skip gracefully (forward-compatible)
        return null;
    }
  }
}
