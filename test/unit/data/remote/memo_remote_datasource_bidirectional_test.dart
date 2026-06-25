// Tests for bidirectional sync remote datasource changes:
// - create uses PUT /memos/{id} (upsert with client id)
// - update uses PUT /memos/{id} (same as create)
// - getSince includes include_deleted=true query param
// - _fromJson parses deleted_at field

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/data/datasources/remote/memo_remote_datasource.dart';
import 'package:memo_everywhere/data/models/memo_model.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late MemoRemoteDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDio = MockDio();
    dataSource = MemoRemoteDataSourceImpl(dio: mockDio);
  });

  group('MemoRemoteDataSource bidirectional sync', () {
    group('T-DS-001: create uses PUT /memos/{id} upsert with client id', () {
      test('create calls PUT /memos/{id} with model.id in path', () async {
        // Arrange
        final now = DateTime.utc(2026, 1, 1);
        final model = MemoModel(
          id: 'client-uuid-123',
          title: 'Test',
          content: 'Content',
          createdAt: now,
          updatedAt: now,
        );
        when(() => mockDio.put<dynamic>(
              '/memos/${model.id}',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response<dynamic>(
              data: <String, dynamic>{
                'id': model.id,
                'user_id': 'u1',
                'title': 'Test',
                'content': 'Content',
                'voice_url': null,
                'markdown_enabled': false,
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
                'version': 1,
                'deleted_at': null,
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/memos/${model.id}'),
            ));

        // Act
        await dataSource.create(model);

        // Assert: must have called PUT with the client id in the path
        verify(() => mockDio.put<dynamic>(
              '/memos/${model.id}',
              data: any(named: 'data'),
            )).called(1);
      });

      test('create PUT body contains title, content, updated_at', () async {
        // Arrange
        final now = DateTime.utc(2026, 6, 15);
        final model = MemoModel(
          id: 'abc-def',
          title: 'My Title',
          content: 'Body text',
          createdAt: now,
          updatedAt: now,
        );

        Map<String, dynamic>? capturedData;
        when(() => mockDio.put<dynamic>(
              '/memos/${model.id}',
              data: any(named: 'data'),
            )).thenAnswer((invocation) async {
          capturedData = invocation.namedArguments[const Symbol('data')]
              as Map<String, dynamic>;
          return Response<dynamic>(
            data: <String, dynamic>{
              'id': model.id,
              'user_id': 'u1',
              'title': 'My Title',
              'content': 'Body text',
              'voice_url': null,
              'markdown_enabled': false,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
              'version': 1,
              'deleted_at': null,
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/memos/${model.id}'),
          );
        });

        // Act
        await dataSource.create(model);

        // Assert: body must include the right fields
        expect(capturedData, isNotNull);
        expect(capturedData!['title'], equals('My Title'));
        expect(capturedData!['content'], equals('Body text'));
        expect(capturedData!['updated_at'], equals(now.toIso8601String()));
      });
    });

    group('T-DS-002: update also uses PUT /memos/{id}', () {
      test('update calls PUT /memos/{id} identically to create', () async {
        // Arrange
        final now = DateTime.utc(2026, 2, 1);
        final model = MemoModel(
          id: 'existing-memo-id',
          title: 'Updated',
          content: 'Updated content',
          createdAt: now,
          updatedAt: now,
        );
        when(() => mockDio.put<dynamic>(
              '/memos/${model.id}',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response<dynamic>(
              data: <String, dynamic>{
                'id': model.id,
                'user_id': 'u1',
                'title': 'Updated',
                'content': 'Updated content',
                'voice_url': null,
                'markdown_enabled': false,
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
                'version': 2,
                'deleted_at': null,
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/memos/${model.id}'),
            ));

        // Act
        await dataSource.update(model);

        // Assert: update also calls PUT
        verify(() => mockDio.put<dynamic>(
              '/memos/${model.id}',
              data: any(named: 'data'),
            )).called(1);
      });
    });

    group('T-DS-003: getSince sends include_deleted=true', () {
      test('getSince includes include_deleted query param', () async {
        // Arrange
        final since = DateTime.utc(2026, 6, 1);
        Map<String, dynamic>? capturedParams;

        when(() => mockDio.get<dynamic>(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((invocation) async {
          capturedParams = invocation.namedArguments[const Symbol('queryParameters')]
              as Map<String, dynamic>;
          return Response<dynamic>(
            data: <dynamic>[],
            statusCode: 200,
            requestOptions: RequestOptions(path: '/memos'),
          );
        });

        // Act
        await dataSource.getSince(since);

        // Assert: must include include_deleted: true
        expect(capturedParams, isNotNull);
        expect(capturedParams!['include_deleted'], isTrue);
        expect(capturedParams!['since'], equals(since.toIso8601String()));
      });
    });

    group('T-DS-004: _fromJson parses deleted_at', () {
      test('getAll parses deleted_at when present', () async {
        // Arrange
        final now = DateTime.utc(2026, 1, 1);
        final deletedAt = DateTime.utc(2026, 6, 20);
        when(() => mockDio.get<dynamic>(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response<dynamic>(
              data: <dynamic>[
                <String, dynamic>{
                  'id': 'deleted-memo',
                  'user_id': 'u1',
                  'title': 'Old',
                  'content': 'old content',
                  'voice_url': null,
                  'markdown_enabled': false,
                  'created_at': now.toIso8601String(),
                  'updated_at': now.toIso8601String(),
                  'version': 1,
                  'deleted_at': deletedAt.toIso8601String(),
                },
              ],
              statusCode: 200,
              requestOptions: RequestOptions(path: '/memos'),
            ));

        // Act
        final memos = await dataSource.getAll();

        // Assert: deletedAt field is populated
        expect(memos, hasLength(1));
        expect(memos.first.deletedAt, isNotNull);
        expect(memos.first.deletedAt, equals(deletedAt));
      });

      test('getAll parsest deleted_at as null when absent', () async {
        // Arrange
        final now = DateTime.utc(2026, 1, 1);
        when(() => mockDio.get<dynamic>(
              any(),
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => Response<dynamic>(
              data: <dynamic>[
                <String, dynamic>{
                  'id': 'active-memo',
                  'user_id': 'u1',
                  'title': 'Active',
                  'content': 'content',
                  'voice_url': null,
                  'markdown_enabled': false,
                  'created_at': now.toIso8601String(),
                  'updated_at': now.toIso8601String(),
                  'version': 1,
                  'deleted_at': null,
                },
              ],
              statusCode: 200,
              requestOptions: RequestOptions(path: '/memos'),
            ));

        // Act
        final memos = await dataSource.getAll();

        // Assert: deletedAt is null for non-deleted memos
        expect(memos, hasLength(1));
        expect(memos.first.deletedAt, isNull);
      });
    });
  });
}
