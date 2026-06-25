// Unit tests for AuthNotifier (SPEC-BACKEND-001 auth)
//
// Tests define the contract:
//   - Initial state is AuthState.loggedOut
//   - login success stores tokens and transitions to loggedIn with email
//   - login failure with bad credentials sets error state
//   - login failure with network error sets error state
//   - register success does not auto-login (returns to idle)
//   - logout clears tokens and transitions to loggedOut

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/core/network/dio_config.dart';
import 'package:memo_everywhere/data/datasources/remote/auth_remote_datasource.dart';
import 'package:memo_everywhere/data/datasources/remote/backend_stt_service.dart';
import 'package:memo_everywhere/presentation/state/auth_provider.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockSecureTokenStore extends Mock implements SecureTokenStore {}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ProviderContainer buildContainer({
  required AuthRemoteDataSource dataSource,
  required SecureTokenStore tokenStore,
}) {
  return ProviderContainer(
    overrides: [
      authRemoteDataSourceProvider.overrideWithValue(dataSource),
      secureTokenStoreProvider.overrideWithValue(tokenStore),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthRemoteDataSource mockDataSource;
  late MockSecureTokenStore mockTokenStore;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  setUp(() {
    mockDataSource = MockAuthRemoteDataSource();
    mockTokenStore = MockSecureTokenStore();

    // Default: writeTokens, writeEmail, and clear are no-ops
    when(
      () => mockTokenStore.writeTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockTokenStore.writeEmail(any()),
    ).thenAnswer((_) async {});
    when(() => mockTokenStore.clear()).thenAnswer((_) async {});
  });

  group('AuthNotifier.restoreSession', () {
    test('restores to AuthLoggedIn when access token and email are both present',
        () async {
      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => 'some-access-token');
      when(() => mockTokenStore.readEmail())
          .thenAnswer((_) async => 'restored@test.com');

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).restoreSession();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthLoggedIn>());
      expect((state as AuthLoggedIn).email, equals('restored@test.com'));
    });

    test('stays AuthLoggedOut when no access token is stored', () async {
      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => null);
      when(() => mockTokenStore.readEmail())
          .thenAnswer((_) async => 'restored@test.com');

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).restoreSession();

      expect(container.read(authNotifierProvider), isA<AuthLoggedOut>());
    });

    test('stays AuthLoggedOut when token is present but email is absent',
        () async {
      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => 'some-access-token');
      when(() => mockTokenStore.readEmail()).thenAnswer((_) async => null);

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).restoreSession();

      expect(container.read(authNotifierProvider), isA<AuthLoggedOut>());
    });

    test('never throws even when token store throws unexpectedly', () async {
      when(() => mockTokenStore.readAccessToken())
          .thenThrow(Exception('storage error'));
      when(() => mockTokenStore.readEmail())
          .thenAnswer((_) async => 'user@test.com');

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      // Must not throw; best-effort restore
      await expectLater(
        container.read(authNotifierProvider.notifier).restoreSession(),
        completes,
      );
      expect(container.read(authNotifierProvider), isA<AuthLoggedOut>());
    });
  });

  group('AuthNotifier.login — persists email', () {
    test('login success calls writeEmail with the logged-in email', () async {
      when(() => mockDataSource.login('user@test.com', 'password123'))
          .thenAnswer(
        (_) async => const TokenPair(
          accessToken: 'access-abc',
          refreshToken: 'refresh-xyz',
        ),
      );

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .login('user@test.com', 'password123');

      verify(() => mockTokenStore.writeEmail('user@test.com')).called(1);
    });
  });

  group('AuthNotifier — initial state', () {
    test('initial state is AuthState.loggedOut', () {
      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthLoggedOut>());
    });
  });

  group('AuthNotifier.login — success', () {
    test('login success stores both tokens in secure storage', () async {
      when(() => mockDataSource.login('user@test.com', 'password123'))
          .thenAnswer(
        (_) async => const TokenPair(
          accessToken: 'access-abc',
          refreshToken: 'refresh-xyz',
        ),
      );

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .login('user@test.com', 'password123');

      verify(
        () => mockTokenStore.writeTokens(
          accessToken: 'access-abc',
          refreshToken: 'refresh-xyz',
        ),
      ).called(1);
    });

    test('login success transitions state to AuthLoggedIn with email',
        () async {
      when(() => mockDataSource.login('user@test.com', 'password123'))
          .thenAnswer(
        (_) async => const TokenPair(
          accessToken: 'access-abc',
          refreshToken: 'refresh-xyz',
        ),
      );

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .login('user@test.com', 'password123');

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthLoggedIn>());
      expect((state as AuthLoggedIn).email, equals('user@test.com'));
    });
  });

  group('AuthNotifier.login — failure', () {
    test('login with wrong credentials sets AuthError state', () async {
      when(() => mockDataSource.login('wrong@test.com', 'badpass')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/login'),
            statusCode: 401,
            data: <String, dynamic>{'detail': 'Incorrect credentials'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .login('wrong@test.com', 'badpass');

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).message, isNotEmpty);
    });

    test('login network failure sets AuthError state', () async {
      when(() => mockDataSource.login(any(), any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          type: DioExceptionType.connectionError,
        ),
      );

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .login('user@test.com', 'pass');

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthError>());
    });
  });

  group('AuthNotifier.register', () {
    test('register success transitions back to loggedOut (no auto-login)',
        () async {
      when(() => mockDataSource.register('new@test.com', 'newpass'))
          .thenAnswer((_) async => 'user-id-123');

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .register('new@test.com', 'newpass');

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthLoggedOut>());
    });

    test('register failure sets AuthError state', () async {
      when(() => mockDataSource.register(any(), any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/register'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/register'),
            statusCode: 409,
            data: <String, dynamic>{'detail': 'Email already registered'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .register('existing@test.com', 'pass');

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthError>());
    });
  });

  group('AuthNotifier.logout', () {
    test('logout clears tokens in secure storage', () async {
      when(() => mockDataSource.login(any(), any())).thenAnswer(
        (_) async => const TokenPair(
          accessToken: 'access-abc',
          refreshToken: 'refresh-xyz',
        ),
      );

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      // First login
      await container
          .read(authNotifierProvider.notifier)
          .login('user@test.com', 'pass');

      // Then logout
      await container.read(authNotifierProvider.notifier).logout();

      verify(() => mockTokenStore.clear()).called(1);
    });

    test('logout transitions state to AuthLoggedOut', () async {
      when(() => mockDataSource.login(any(), any())).thenAnswer(
        (_) async => const TokenPair(
          accessToken: 'access-abc',
          refreshToken: 'refresh-xyz',
        ),
      );

      final container = buildContainer(
        dataSource: mockDataSource,
        tokenStore: mockTokenStore,
      );
      addTearDown(container.dispose);

      // First login
      await container
          .read(authNotifierProvider.notifier)
          .login('user@test.com', 'pass');
      expect(container.read(authNotifierProvider), isA<AuthLoggedIn>());

      // Then logout
      await container.read(authNotifierProvider.notifier).logout();

      expect(container.read(authNotifierProvider), isA<AuthLoggedOut>());
    });
  });
}
