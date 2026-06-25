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
