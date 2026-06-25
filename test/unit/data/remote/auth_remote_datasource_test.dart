import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:memo_everywhere/data/datasources/remote/auth_remote_datasource.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late AuthRemoteDataSource dataSource;

  setUp(() {
    mockDio = MockDio();
    dataSource = AuthRemoteDataSourceImpl(dio: mockDio);
  });

  group('AuthRemoteDataSource', () {
    test('login returns TokenPair on success', () async {
      // Arrange
      when(() => mockDio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response<dynamic>(
                data: {
                  'access_token': 'access.jwt.token',
                  'refresh_token': 'refresh.jwt.token',
                  'token_type': 'bearer',
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: '/auth/login'),
              ));

      // Act
      final result = await dataSource.login('user@test.com', 'Pass123!');

      // Assert
      expect(result.accessToken, equals('access.jwt.token'));
      expect(result.refreshToken, equals('refresh.jwt.token'));
    });

    test('register returns user id on success', () async {
      // Arrange
      when(() => mockDio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response<dynamic>(
                data: {'id': 'user-123', 'email': 'user@test.com'},
                statusCode: 201,
                requestOptions: RequestOptions(path: '/auth/register'),
              ));

      // Act
      final userId = await dataSource.register('user@test.com', 'Pass123!');

      // Assert
      expect(userId, equals('user-123'));
    });

    test('refresh returns new access token', () async {
      // Arrange
      when(() => mockDio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response<dynamic>(
                data: {'access_token': 'new.access.token', 'token_type': 'bearer'},
                statusCode: 200,
                requestOptions: RequestOptions(path: '/auth/refresh'),
              ));

      // Act
      final newToken = await dataSource.refreshToken('old.refresh.token');

      // Assert
      expect(newToken, equals('new.access.token'));
    });
  });
}
