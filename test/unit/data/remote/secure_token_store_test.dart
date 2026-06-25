// Unit tests for extended SecureTokenStore (SPEC-BACKEND-001 auth)
//
// Tests define the contract:
//   - writeTokens stores both access and refresh tokens
//   - readAccessToken returns stored access token
//   - readRefreshToken returns stored refresh token
//   - clear removes both tokens from storage

import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/data/datasources/remote/backend_stt_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockFlutterSecureStorage mockStorage;
  late FlutterSecureTokenStore tokenStore;

  setUpAll(() {
    // No fallback values needed — all calls use named parameters.
  });

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    tokenStore = FlutterSecureTokenStore(storage: mockStorage);
  });

  group('FlutterSecureTokenStore.writeTokens', () {
    test('writes access token to secure storage with key access_token',
        () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await tokenStore.writeTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      );

      verify(
        () => mockStorage.write(key: 'access_token', value: 'access-123'),
      ).called(1);
    });

    test('writes refresh token to secure storage with key refresh_token',
        () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await tokenStore.writeTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
      );

      verify(
        () => mockStorage.write(key: 'refresh_token', value: 'refresh-456'),
      ).called(1);
    });
  });

  group('FlutterSecureTokenStore.readRefreshToken', () {
    test('returns stored refresh token', () async {
      when(() => mockStorage.read(key: 'refresh_token'))
          .thenAnswer((_) async => 'my-refresh-token');

      final result = await tokenStore.readRefreshToken();

      expect(result, equals('my-refresh-token'));
    });

    test('returns null when no refresh token is stored', () async {
      when(() => mockStorage.read(key: 'refresh_token'))
          .thenAnswer((_) async => null);

      final result = await tokenStore.readRefreshToken();

      expect(result, isNull);
    });
  });

  group('FlutterSecureTokenStore.clear', () {
    test('deletes access_token from secure storage', () async {
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await tokenStore.clear();

      verify(() => mockStorage.delete(key: 'access_token')).called(1);
    });

    test('deletes refresh_token from secure storage', () async {
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await tokenStore.clear();

      verify(() => mockStorage.delete(key: 'refresh_token')).called(1);
    });
  });

  group('FlutterSecureTokenStore.readAccessToken (unchanged)', () {
    test('returns stored access token', () async {
      when(() => mockStorage.read(key: 'access_token'))
          .thenAnswer((_) async => 'my-access-token');

      final result = await tokenStore.readAccessToken();

      expect(result, equals('my-access-token'));
    });
  });
}
