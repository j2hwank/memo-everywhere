import 'package:hive/hive.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/memo_model.dart';

/// Abstract interface for local Hive-based memo persistence.
abstract interface class MemoLocalDataSource {
  Future<List<MemoModel>> getAll();
  Future<void> create(MemoModel model);
  Future<void> update(MemoModel model);
  Future<void> delete(String id);
}

/// Hive implementation. Uses [AppConstants.memosBoxName] as the box key.
///
/// The box must be opened by [main] before this datasource is used.
class MemoLocalDataSourceImpl implements MemoLocalDataSource {
  MemoLocalDataSourceImpl() : _box = Hive.box<MemoModel>(AppConstants.memosBoxName);

  final Box<MemoModel> _box;

  @override
  Future<List<MemoModel>> getAll() async {
    return _box.values.toList();
  }

  @override
  Future<void> create(MemoModel model) async {
    await _box.put(model.id, model);
  }

  @override
  Future<void> update(MemoModel model) async {
    await _box.put(model.id, model);
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
