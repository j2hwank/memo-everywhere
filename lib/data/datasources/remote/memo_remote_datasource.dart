import 'package:dio/dio.dart';
import '../../models/memo_model.dart';

/// Abstract interface for memo remote data operations.
abstract interface class MemoRemoteDataSource {
  /// Fetch all memos from the server.
  Future<List<MemoModel>> getAll();

  /// Fetch memos updated after [since] (incremental sync, REQ-B-005).
  Future<List<MemoModel>> getSince(DateTime since);

  /// Create a new memo on the server.
  Future<void> create(MemoModel model);

  /// Update an existing memo (LWW, REQ-B-004).
  Future<void> update(MemoModel model);

  /// Soft-delete a memo on the server.
  Future<void> delete(String id);
}

/// Dio-based implementation targeting the FastAPI backend.
class MemoRemoteDataSourceImpl implements MemoRemoteDataSource {
  const MemoRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<MemoModel>> getAll() async {
    final response = await _dio.get<dynamic>(
      '/memos',
      queryParameters: <String, dynamic>{},
    );
    return _parseList((response.data as List<dynamic>?) ?? []);
  }

  @override
  Future<List<MemoModel>> getSince(DateTime since) async {
    // include_deleted=true ensures soft-deleted memos are returned so the
    // sync layer can propagate deletions to local storage (REQ-B-006).
    final response = await _dio.get<dynamic>(
      '/memos',
      queryParameters: <String, dynamic>{
        'since': since.toIso8601String(),
        'include_deleted': true,
      },
    );
    return _parseList((response.data as List<dynamic>?) ?? []);
  }

  // @MX:NOTE: [AUTO] create and update both use PUT /memos/{id} (upsert).
  // The backend treats PUT as idempotent: client supplies the canonical id,
  // enabling offline-first creation without a server round-trip for id assignment.
  @override
  Future<void> create(MemoModel model) async {
    await _dio.put<dynamic>(
      '/memos/${model.id}',
      data: <String, dynamic>{
        'title': model.title,
        'content': model.content,
        'updated_at': model.updatedAt.toIso8601String(),
      },
    );
  }

  @override
  Future<void> update(MemoModel model) async {
    await _dio.put<dynamic>(
      '/memos/${model.id}',
      data: <String, dynamic>{
        'title': model.title,
        'content': model.content,
        'updated_at': model.updatedAt.toIso8601String(),
      },
    );
  }

  @override
  Future<void> delete(String id) async {
    await _dio.delete<dynamic>('/memos/$id');
  }

  List<MemoModel> _parseList(List<dynamic> data) {
    return data
        .cast<Map<String, dynamic>>()
        .map(_fromJson)
        .toList();
  }

  MemoModel _fromJson(Map<String, dynamic> json) {
    final deletedAtRaw = json['deleted_at'] as String?;
    return MemoModel(
      id: json['id'] as String,
      title: json['title'] as String?,
      content: (json['content'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: deletedAtRaw != null ? DateTime.parse(deletedAtRaw) : null,
    );
  }
}
