import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memo_everywhere/core/network/token_refresh_interceptor.dart';
import 'package:memo_everywhere/data/datasources/remote/backend_stt_service.dart';

// ---------------------------------------------------------------------------
// Base URL configuration
// ---------------------------------------------------------------------------

/// Backend base URL resolved at compile time.
///
/// On-device usage:
///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
///
/// Default is localhost for simulator / unit tests.
const String _kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

// ---------------------------------------------------------------------------
// Auth interceptor
// ---------------------------------------------------------------------------

/// Attaches `Authorization: Bearer <token>` to every request when a token
/// is present in [SecureTokenStore].
///
/// Requests that already carry an Authorization header are left unchanged
/// (e.g. requests from [BackendSttServiceImpl] that build the header manually
/// for full Content-Type control — they pass the header explicitly).
//
// @MX:NOTE: [AUTO] This interceptor is a convenience layer for future
// datasources. BackendSttServiceImpl sets its own Authorization header to
// also control Content-Type in the same Options object.
class _AuthInterceptor extends Interceptor {
  const _AuthInterceptor({required SecureTokenStore tokenStore})
      : _tokenStore = tokenStore;

  final SecureTokenStore _tokenStore;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!options.headers.containsKey('Authorization')) {
      final token = await _tokenStore.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}

// ---------------------------------------------------------------------------
// Dio factory
// ---------------------------------------------------------------------------

/// Creates a [Dio] instance configured for the memo-everywhere backend.
///
/// The returned client has two interceptors applied in order:
/// 1. [_AuthInterceptor] — attaches `Authorization: Bearer <token>` on every
///    outgoing request (when a header is not already present).
/// 2. [TokenRefreshInterceptor] — on HTTP 401, transparently refreshes the
///    access token via a bare Dio (no interceptors) and retries once.
Dio createDio({required SecureTokenStore tokenStore}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // Bare Dio used exclusively for the /auth/refresh call so it does NOT
  // recurse through the TokenRefreshInterceptor on the main client.
  // @MX:NOTE: [AUTO] _refreshDio is intentionally interceptor-free to prevent
  // recursive 401-refresh loops when the refresh endpoint itself fails.
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(_AuthInterceptor(tokenStore: tokenStore));
  dio.interceptors.add(
    TokenRefreshInterceptor(
      tokenStore: tokenStore,
      doRefresh: (refreshToken) async {
        final response = await refreshDio.post<dynamic>(
          '/auth/refresh',
          data: <String, dynamic>{'refresh_token': refreshToken},
        );
        final data = response.data as Map<String, dynamic>;
        return data['access_token'] as String;
      },
      retryCaller: dio.fetch,
    ),
  );

  return dio;
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Provider for [SecureTokenStore].
final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  return const FlutterSecureTokenStore();
});

/// Provider for the shared [Dio] instance.
///
// @MX:ANCHOR: [AUTO] dioProvider — shared HTTP client
// @MX:REASON: Used by BackendSttServiceImpl and future remote datasources;
// fan_in >= 3 anticipated.
final dioProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(secureTokenStoreProvider);
  return createDio(tokenStore: tokenStore);
});
