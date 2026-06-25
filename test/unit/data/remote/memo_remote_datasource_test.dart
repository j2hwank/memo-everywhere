import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:memo_everywhere/data/datasources/remote/memo_remote_datasource.dart';
import 'package:memo_everywhere/data/models/memo_model.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late MemoRemoteDataSource dataSource;

  setUp(() {
    mockDio = MockDio();
    dataSource = MemoRemoteDataSourceImpl(dio: mockDio);
  });

  group('MemoRemoteDataSource', () {
    test('getAll returns list of memos from GET /memos', () async {
      // Arrange
      final now = DateTime.utc(2026, 1, 1);
      when(() => mockDio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response<dynamic>(
                data: [
                  {
                    'id': 'memo-1',
                    'user_id': 'user-1',
                    'title': 'Test',
                    'content': 'Content',
                    'voice_url': null,
                    'markdown_enabled': false,
                    'created_at': now.toIso8601String(),
                    'updated_at': now.toIso8601String(),
                    'version': 1,
                    'deleted_at': null,
                  }
                ],
                statusCode: 200,
                requestOptions: RequestOptions(path: '/memos'),
              ));

      // Act
      final memos = await dataSource.getAll();

      // Assert
      expect(memos, hasLength(1));
      expect(memos.first.id, equals('memo-1'));
    });

    test('create sends PUT /memos/{id} with client id (upsert)', () async {
      // Arrange — create now uses PUT upsert (client-supplied id)
      final now = DateTime.utc(2026, 1, 1);
      final model = MemoModel(
        id: 'new-memo',
        title: 'New',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );
      when(() => mockDio.put<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response<dynamic>(
                data: {
                  'id': 'new-memo',
                  'user_id': 'user-1',
                  'title': 'New',
                  'content': 'Content',
                  'voice_url': null,
                  'markdown_enabled': false,
                  'created_at': now.toIso8601String(),
                  'updated_at': now.toIso8601String(),
                  'version': 1,
                  'deleted_at': null,
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: '/memos/new-memo'),
              ));

      // Act & Assert (no exception means success)
      await dataSource.create(model);
      verify(() => mockDio.put<dynamic>('/memos/new-memo', data: any(named: 'data'))).called(1);
    });

    test('getSince fetches memos updated after given timestamp', () async {
      // Arrange
      final since = DateTime.utc(2026, 6, 1);
      when(() => mockDio.get<dynamic>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response<dynamic>(
            data: <dynamic>[],
            statusCode: 200,
            requestOptions: RequestOptions(path: '/memos'),
          ));

      // Act
      final result = await dataSource.getSince(since);

      // Assert
      expect(result, isEmpty);
    });
  });
}
