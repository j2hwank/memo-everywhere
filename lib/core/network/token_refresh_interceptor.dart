import 'dart:async';

import 'package:dio/dio.dart';
import 'package:memo_everywhere/data/datasources/remote/backend_stt_service.dart';

// ---------------------------------------------------------------------------
// TokenRefreshInterceptor
// ---------------------------------------------------------------------------

/// Dio [Interceptor] that silently refreshes an expired JWT access token on
/// HTTP 401 and retries the original request exactly once.
///
/// ### Guarantees
///
/// * **Loop guard** — auth endpoints (`/auth/refresh`, `/auth/login`,
///   `/auth/register`) are never themselves refresh-retried.
/// * **Retry-once** — each request is retried at most once; the
///   [retriedKey] flag in `RequestOptions.extra` prevents a second attempt.
/// * **Single-flight** — if multiple concurrent requests receive 401, only
///   ONE `/auth/refresh` call is issued; others wait for and reuse its result.
/// * **Fail-safe** — when refresh fails, [SecureTokenStore.clear] is called
///   (effectively logging out) and the original 401 error is propagated.
///
// @MX:ANCHOR: [AUTO] TokenRefreshInterceptor — JWT silent refresh boundary
// @MX:REASON: All authenticated Dio requests route through this interceptor;
// fan_in >= 3 (voice, sync, memo datasources share the dioProvider).
// @MX:WARN: [AUTO] mutable _refreshFuture shared across concurrent requests
// @MX:REASON: Single-flight lock; must be reset to null after each
// refresh attempt (success or failure) to avoid permanent deadlock.
class TokenRefreshInterceptor extends Interceptor {
  TokenRefreshInterceptor({
    required SecureTokenStore tokenStore,
    required Future<String> Function(String refreshToken) doRefresh,
    required Future<Response<dynamic>> Function(RequestOptions) retryCaller,
  })  : _tokenStore = tokenStore,
        _doRefresh = doRefresh,
        _retryCaller = retryCaller;

  final SecureTokenStore _tokenStore;
  final Future<String> Function(String) _doRefresh;
  final Future<Response<dynamic>> Function(RequestOptions) _retryCaller;

  // Single-flight: non-null while a refresh is in progress.
  Future<String>? _refreshFuture;

  // ---------------------------------------------------------------------------
  // Public constants
  // ---------------------------------------------------------------------------

  /// Key used in [RequestOptions.extra] to mark a request that has already
  /// been retried once after a token refresh.
  static const String retriedKey = '_tokenRefreshRetried';

  /// Auth endpoint path segments that must never be refresh-retried.
  static const _skipPaths = {
    '/auth/refresh',
    '/auth/login',
    '/auth/register',
  };

  // ---------------------------------------------------------------------------
  // Interceptor override
  // ---------------------------------------------------------------------------

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only handle HTTP 401 Bad-Response errors.
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final path = err.requestOptions.path;

    // Loop guard: never attempt refresh for auth endpoints.
    if (_skipPaths.any(path.contains)) {
      handler.next(err);
      return;
    }

    // Retry-once guard: if this request was already retried, give up.
    if (err.requestOptions.extra[retriedKey] == true) {
      handler.next(err);
      return;
    }

    // Attempt token refresh (single-flight).
    final String newToken;
    try {
      newToken = await _ensureRefreshed();
    } catch (_) {
      // Refresh failed; tokens already cleared inside _ensureRefreshed.
      handler.next(err);
      return;
    }

    // Retry the original request exactly once with the new token.
    final retryOptions = err.requestOptions
      ..extra[retriedKey] = true
      ..headers['Authorization'] = 'Bearer $newToken';

    try {
      final retryResponse = await _retryCaller(retryOptions);
      handler.resolve(retryResponse);
    } catch (retryErr) {
      if (retryErr is DioException) {
        handler.next(retryErr);
      } else {
        handler.next(
          DioException(
            requestOptions: retryOptions,
            error: retryErr,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Single-flight refresh logic
  // ---------------------------------------------------------------------------

  /// Returns a [Future] that resolves with the new access token.
  ///
  /// If a refresh is already in-flight, the existing [Future] is returned so
  /// that concurrent callers share a single `/auth/refresh` call.
  Future<String> _ensureRefreshed() {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }
    // @MX:NOTE: [AUTO] _refreshFuture is set before await so that subsequent
    // concurrent callers immediately see the in-flight future (single-flight).
    _refreshFuture = _performRefresh().whenComplete(() {
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<String> _performRefresh() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null) {
      throw const _NoRefreshTokenException();
    }

    try {
      final newAccessToken = await _doRefresh(refreshToken);
      await _tokenStore.writeAccessToken(newAccessToken);
      return newAccessToken;
    } catch (e) {
      // On any refresh failure, clear all stored tokens (force logout).
      await _tokenStore.clear();
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Internal sentinel exception
// ---------------------------------------------------------------------------

class _NoRefreshTokenException implements Exception {
  const _NoRefreshTokenException();
}
