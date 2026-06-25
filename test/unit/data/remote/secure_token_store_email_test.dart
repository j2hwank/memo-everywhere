// Unit tests for SecureTokenStore email persistence (session restore).
//
// Tests define the contract:
//   - writeEmail stores the user email under key 'user_email'
//   - readEmail returns the stored email
//   - readEmail returns null when no email is stored
//   - clear also removes the stored email (user_email key)

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

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    tokenStore = FlutterSecureTokenStore(storage: mockStorage);
  });

  group('FlutterSecureTokenStore.writeEmail', () {
    test('writes email to secure storage with key user_email', () async {
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await tokenStore.writeEmail('user@example.com');

      verify(
        () => mockStorage.write(key: 'user_email', value: 'user@example.com'),
      ).called(1);
    });
  });

  group('FlutterSecureTokenStore.readEmail', () {
    test('returns stored email', () async {
      when(() => mockStorage.read(key: 'user_email'))
          .thenAnswer((_) async => 'stored@example.com');

      final result = await tokenStore.readEmail();

      expect(result, equals('stored@example.com'));
    });

    test('returns null when no email is stored', () async {
      when(() => mockStorage.read(key: 'user_email'))
          .thenAnswer((_) async => null);

      final result = await tokenStore.readEmail();

      expect(result, isNull);
    });
  });

  group('FlutterSecureTokenStore.clear — also removes email', () {
    test('deletes user_email from secure storage', () async {
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await tokenStore.clear();

      verify(() => mockStorage.delete(key: 'user_email')).called(1);
    });
  });
}
