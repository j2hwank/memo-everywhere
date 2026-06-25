// Unit tests for TokenRefreshInterceptor (JWT silent refresh on HTTP 401)
//
// RED phase: all tests below are expected to FAIL until the interceptor
// is implemented (GREEN phase).
//
// Behaviour contracts:
//   T-001 401 on normal request → refresh once → new token persisted → retry → success
//   T-002 refresh call fails    → tokens cleared → original 401 propagated
//   T-003 401 on /auth/refresh  → NO refresh attempted (loop guard)
//   T-004 401 on /auth/login    → NO refresh attempted (loop guard)
//   T-005 request already retried (extra flag) → NOT retried again
//   T-006 concurrent 401s       → doRefresh called exactly once (single-flight)
//   T-007 no refresh token stored → NO refresh → original error propagated
//   T-008 non-401 error         → passed through unchanged

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/core/network/token_refresh_interceptor.dart';
import 'package:memo_everywhere/data/datasources/remote/backend_stt_service.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockSecureTokenStore extends Mock implements SecureTokenStore {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [DioException] with the given [statusCode] and [path].
DioException _buildDioException({
  required int statusCode,
  required String path,
  Map<String, dynamic>? extra,
}) {
  final requestOptions = RequestOptions(path: path, extra: extra ?? {});
  return DioException(
    requestOptions: requestOptions,
    response: Response<dynamic>(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data: null,
    ),
    type: DioExceptionType.badResponse,
  );
}

/// Builds a successful [Response].
Response<dynamic> _okResponse(RequestOptions options) => Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      data: {'ok': true},
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockSecureTokenStore mockTokenStore;
  late MockErrorInterceptorHandler mockHandler;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(
      DioException(requestOptions: RequestOptions(path: '')),
    );
    registerFallbackValue(
      Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
      ),
    );
  });

  setUp(() {
    mockTokenStore = MockSecureTokenStore();
    mockHandler = MockErrorInterceptorHandler();
  });

  // -------------------------------------------------------------------------
  // T-001: Normal 401 → refresh → retry → success
  // -------------------------------------------------------------------------
  group('T-001: 401 on normal request triggers refresh-and-retry', () {
    test(
        'calls doRefresh once, persists new token, retries request, resolves with retried response',
        () async {
      // Arrange
      when(() => mockTokenStore.readRefreshToken())
          .thenAnswer((_) async => 'old-refresh-token');
      when(() => mockTokenStore.writeAccessToken(any()))
          .thenAnswer((_) async {});
      when(() => mockHandler.resolve(any())).thenReturn(null);

      var doRefreshCallCount = 0;
      var retryCallCount = 0;

      final err = _buildDioException(statusCode: 401, path: '/memos');
      final retryResponse = _okResponse(err.requestOptions);

      final interceptor = TokenRefreshInterceptor(
        tokenStore: mockTokenStore,
        doRefresh: (rt) async {
          doRefreshCallCount++;
          expect(rt, equals('old-refresh-token'));
          return 'new-access-token';
        },
        retryCaller: (opts) async {
          retryCallCount++;
          expect(opts.headers['Authorization'],
              equals('Bearer new-access-token'));
          expect(opts.extra[TokenRefreshInterceptor.retriedKey], isTrue);
          return retryResponse;
        },
      );

      // Act
      await interceptor.onError(err, mockHandler);

      // Assert
      expect(doRefreshCallCount, equals(1));
      expect(retryCallCount, equals(1));
      verify(() => mockTokenStore.writeAccessToken('new-access-token'))
          .called(1);
      verify(() => mockHandler.resolve(retryResponse)).called(1);
      verifyNever(() => mockHandler.next(any()));
    });
  });

  // -------------------------------------------------------------------------
  // T-002: Refresh call fails → tokens cleared → original error propagated
  // -------------------------------------------------------------------------
  group('T-002: refresh failure clears tokens and propagates original error',
      () {
    test('calls clear() and forwards original 401 without retry', () async {
      // Arrange
      when(() => mockTokenStore.readRefreshToken())
          .thenAnswer((_) async => 'stale-refresh');
      when(() => mockTokenStore.clear()).thenAnswer((_) async {});
      when(() => mockHandler.next(any())).thenReturn(null);

      var retryCallCount = 0;

      final err = _buildDioException(statusCode: 401, path: '/memos');

      final interceptor = TokenRefreshInterceptor(
        tokenStore: mockTokenStore,
        doRefresh: (_) async =>
            throw DioException(requestOptions: err.requestOptions),
        retryCaller: (opts) async {
          retryCallCount++;
          return _okResponse(opts);
        },
      );

      // Act
      await interceptor.onError(err, mockHandler);

      // Assert
      expect(retryCallCount, equals(0));
      verify(() => mockTokenStore.clear()).called(1);
      verify(() => mockHandler.next(err)).called(1);
      verifyNever(() => mockHandler.resolve(any()));
    });
  });

  // -------------------------------------------------------------------------
  // T-003: 401 on /auth/refresh → loop guard → no refresh attempted
  // -------------------------------------------------------------------------
  group('T-003: 401 on /auth/refresh is never refreshed', () {
    test('passes error through without calling doRefresh', () async {
      // Arrange
      when(() => mockHandler.next(any())).thenReturn(null);

      var doRefreshCallCount = 0;
      final err =
          _buildDioException(statusCode: 401, path: '/auth/refresh');

      final interceptor = TokenRefreshInterceptor(
        tokenStore: mockTokenStore,
        doRefresh: (_) async {
          doRefreshCallCount++;
          return 'should-not-be-called';
        },
        retryCaller: (opts) async => _okResponse(opts),
      );

      // Act
      await interceptor.onError(err, mockHandler);

      // Assert
      expect(doRefreshCallCount, equals(0));
      verify(() => mockHandler.next(err)).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // T-004: 401 on /auth/login → loop guard → no refresh attempted
  // -------------------------------------------------------------------------
  group('T-004: 401 on /auth/login is never refreshed', () {
    test('passes error through without calling doRefresh', () async {
      // Arrange
      when(() => mockHandler.next(any())).thenReturn(null);

      var doRefreshCallCount = 0;
      final err =
          _buildDioException(statusCode: 401, path: '/auth/login');

      final interceptor = TokenRefreshInterceptor(
        tokenStore: mockTokenStore,
        doRefresh: (_) async {
          doRefreshCallCount++;
          return 'should-not-be-called';
        },
        retryCaller: (opts) async => _okResponse(opts),
      );

      // Act
      await interceptor.onError(err, mockHandler);

      // Assert
      expect(doRefreshCallCount, equals(0));
      verify(() => mockHandler.next(err)).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // T-005: Already-retried request is NOT retried again
  // -------------------------------------------------------------------------
  group('T-005: retry-once guard prevents infinite loop', () {
    test('passes error through when _retried flag is already set', () async {
      // Arrange
      when(() => mockHandler.next(any())).thenReturn(null);

      var doRefreshCallCount = 0;
      final err = _buildDioException(
        statusCode: 401,
        path: '/memos',
        extra: {TokenRefreshInterceptor.retriedKey: true},
      );

      final interceptor = TokenRefreshInterceptor(
        tokenStore: mockTokenStore,
        doRefresh: (_) async {
          doRefreshCallCount++;
          return 'should-not-be-called';
        },
        retryCaller: (opts) async => _okResponse(opts),
      );

      // Act
      await interceptor.onError(err, mockHandler);

      // Assert
      expect(doRefreshCallCount, equals(0));
      verify(() => mockHandler.next(err)).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // T-006: Concurrent 401s → single-flight (doRefresh called exactly once)
  // -------------------------------------------------------------------------
  group('T-006: concurrent 401s trigger only one refresh call', () {
    test('doRefresh is called exactly once for two simultaneous 401 errors',
        () async {
      // Arrange
      when(() => mockTokenStore.readRefreshToken())
          .thenAnswer((_) async => 'refresh-token');
      when(() => mockTokenStore.writeAccessToken(any()))
          .thenAnswer((_) async {});

      var doRefreshCallCount = 0;
      var retryCallCount = 0;

      final completer = Completer<String>();

      final mockHandler1 = MockErrorInterceptorHandler();
      final mockHandler2 = MockErrorInterceptorHandler();
      when(() => mockHandler1.resolve(any())).thenReturn(null);
      when(() => mockHandler2.resolve(any())).thenReturn(null);

      final err1 = _buildDioException(statusCode: 401, path: '/memos/1');
      final err2 = _buildDioException(statusCode: 401, path: '/memos/2');

      final interceptor = TokenRefreshInterceptor(
        tokenStore: mockTokenStore,
        doRefresh: (_) async {
          doRefreshCallCount++;
          return completer.future; // blocks until we resolve
        },
        retryCaller: (opts) async {
          retryCallCount++;
          return _okResponse(opts);
        },
      );

      // Act: fire both errors concurrently
      final f1 = interceptor.onError(err1, mockHandler1);
      final f2 = interceptor.onError(err2, mockHandler2);

      // Unblock the refresh
      completer.complete('new-access-token');
      await Future.wait(<Future<void>>[f1, f2]);

      // Assert: single refresh call, two retries
      expect(doRefreshCallCount, equals(1),
          reason: 'doRefresh should be called exactly once (single-flight)');
      expect(retryCallCount, equals(2),
          reason: 'both requests should be retried once');
      verify(() => mockTokenStore.writeAccessToken('new-access-token'))
          .called(1);
    });
  });

  // -------------------------------------------------------------------------
  // T-007: No refresh token stored → error propagated without refresh
  // -------------------------------------------------------------------------
  group('T-007: missing refresh token → no refresh attempted', () {
    test('passes 401 error through when refresh token is null', () async {
      // Arrange
      when(() => mockTokenStore.readRefreshToken())
          .thenAnswer((_) async => null);
      when(() => mockHandler.next(any())).thenReturn(null);

      var doRefreshCallCount = 0;
      final err = _buildDioException(statusCode: 401, path: '/memos');

      final interceptor = TokenRefreshInterceptor(
        tokenStore: mockTokenStore,
        doRefresh: (_) async {
          doRefreshCallCount++;
          return 'should-not-be-called';
        },
        retryCaller: (opts) async => _okResponse(opts),
      );

      // Act
      await interceptor.onError(err, mockHandler);

      // Assert
      expect(doRefreshCallCount, equals(0));
      verify(() => mockHandler.next(err)).called(1);
      verifyNever(() => mockHandler.resolve(any()));
    });
  });

  // -------------------------------------------------------------------------
  // T-008: Non-401 errors are passed through unchanged
  // -------------------------------------------------------------------------
  group('T-008: non-401 errors are not intercepted', () {
    test('passes 500 server error through without refresh', () async {
      // Arrange
      when(() => mockHandler.next(any())).thenReturn(null);

      var doRefreshCallCount = 0;
      final err = _buildDioException(statusCode: 500, path: '/memos');

      final interceptor = TokenRefreshInterceptor(
        tokenStore: mockTokenStore,
        doRefresh: (_) async {
          doRefreshCallCount++;
          return 'should-not-be-called';
        },
        retryCaller: (opts) async => _okResponse(opts),
      );

      // Act
      await interceptor.onError(err, mockHandler);

      // Assert
      expect(doRefreshCallCount, equals(0));
      verify(() => mockHandler.next(err)).called(1);
    });

    test('passes connection timeout through without refresh', () async {
      // Arrange
      when(() => mockHandler.next(any())).thenReturn(null);

      var doRefreshCallCount = 0;
      final requestOptions = RequestOptions(path: '/memos');
      final err = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionTimeout,
      );

      final interceptor = TokenRefreshInterceptor(
        tokenStore: mockTokenStore,
        doRefresh: (_) async {
          doRefreshCallCount++;
          return 'should-not-be-called';
        },
        retryCaller: (opts) async => _okResponse(opts),
      );

      // Act
      await interceptor.onError(err, mockHandler);

      // Assert
      expect(doRefreshCallCount, equals(0));
      verify(() => mockHandler.next(err)).called(1);
    });
  });
}
