import 'package:hive/hive.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/memo.dart';

part 'memo_model.g.dart';

// @MX:ANCHOR typeId=0 MUST remain 0 — changing corrupts existing Hive boxes.
// @MX:REASON: HiveAdapter typeId is encoded in the binary box file. If the
//             typeId changes, Hive cannot deserialize previously stored data.
@HiveType(typeId: AppConstants.memoModelTypeId)
class MemoModel extends HiveObject {
  MemoModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    // @MX:NOTE: [AUTO] deletedAt is null for local/non-deleted memos.
    // HiveField(5) — added after initial schema; old boxes read null for missing
    // fields, so backward compatibility is preserved without migration.
    this.deletedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String? title;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  /// Soft-delete timestamp from the server. Null for active memos.
  /// Not written by local CRUD — only populated during remote sync pull.
  @HiveField(5)
  DateTime? deletedAt;

  /// Creates a [MemoModel] from a domain [Memo] entity.
  factory MemoModel.fromMemo(Memo memo) {
    return MemoModel(
      id: memo.id,
      title: memo.title,
      content: memo.content,
      createdAt: memo.createdAt,
      updatedAt: memo.updatedAt,
    );
  }

  /// Converts this model to a domain [Memo] entity.
  Memo toMemo() {
    return Memo(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
