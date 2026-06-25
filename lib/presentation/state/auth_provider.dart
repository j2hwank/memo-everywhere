// Auth state management for SPEC-BACKEND-001 optional login flow.
//
// Provides:
//   - AuthState sealed class hierarchy (loggedOut / loggedIn / loading / error)
//   - AuthNotifier: login, register, logout actions
//   - authRemoteDataSourceProvider: constructs AuthRemoteDataSourceImpl

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memo_everywhere/core/network/dio_config.dart';
import 'package:memo_everywhere/data/datasources/remote/auth_remote_datasource.dart';

// ---------------------------------------------------------------------------
// AuthState — sealed hierarchy
// ---------------------------------------------------------------------------

// @MX:ANCHOR: [AUTO] AuthState — auth state root type
// @MX:REASON: Consumed by AuthNotifier, AuthScreen, and HomePageState
// account icon; fan_in >= 3.
sealed class AuthState {
  const AuthState();
}

/// User is not authenticated.
class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}

/// Authentication operation is in progress.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// User is authenticated.
class AuthLoggedIn extends AuthState {
  const AuthLoggedIn({required this.email});

  final String email;
}

/// An auth operation failed.
class AuthError extends AuthState {
  const AuthError({required this.message});

  final String message;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provider for [AuthRemoteDataSource].
///
// @MX:NOTE: [AUTO] Constructed with shared dioProvider so auth requests
// share the same interceptor stack as other remote datasources.
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRemoteDataSourceImpl(dio: dio);
});

// ---------------------------------------------------------------------------
// AuthNotifier
// ---------------------------------------------------------------------------

// @MX:ANCHOR: [AUTO] AuthNotifier — auth state machine
// @MX:REASON: HomePageState, AuthScreen, and future sync service all consume
// authNotifierProvider; fan_in >= 3.
// @MX:WARN: [AUTO] login/register call remote network; may throw DioException
// @MX:REASON: Network errors surface as AuthError — callers must handle
// loading state to prevent double-submission.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthLoggedOut();

  /// Attempts to log in. On success persists tokens and transitions to
  /// [AuthLoggedIn]. On failure transitions to [AuthError].
  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    try {
      final dataSource = ref.read(authRemoteDataSourceProvider);
      final tokenStore = ref.read(secureTokenStoreProvider);
      final pair = await dataSource.login(email, password);
      await tokenStore.writeTokens(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
      );
      state = AuthLoggedIn(email: email);
    } on DioException catch (e) {
      state = AuthError(message: _messageFromDio(e));
    } catch (e) {
      state = AuthError(message: e.toString());
    }
  }

  /// Registers a new account. On success, returns to [AuthLoggedOut] so the
  /// user can log in manually (no auto-login).
  Future<void> register(String email, String password) async {
    state = const AuthLoading();
    try {
      final dataSource = ref.read(authRemoteDataSourceProvider);
      await dataSource.register(email, password);
      // Registration succeeded — return to logged-out so user can sign in.
      state = const AuthLoggedOut();
    } on DioException catch (e) {
      state = AuthError(message: _messageFromDio(e));
    } catch (e) {
      state = AuthError(message: e.toString());
    }
  }

  /// Clears stored tokens and transitions to [AuthLoggedOut].
  Future<void> logout() async {
    final tokenStore = ref.read(secureTokenStoreProvider);
    await tokenStore.clear();
    state = const AuthLoggedOut();
  }

  static String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    return switch (e.type) {
      DioExceptionType.connectionError => '네트워크에 연결할 수 없습니다',
      DioExceptionType.connectionTimeout => '연결 시간이 초과되었습니다',
      DioExceptionType.badResponse when e.response?.statusCode == 401 =>
        '이메일 또는 비밀번호가 올바르지 않습니다',
      DioExceptionType.badResponse when e.response?.statusCode == 409 =>
        '이미 등록된 이메일입니다',
      _ => '알 수 없는 오류가 발생했습니다',
    };
  }
}

/// Riverpod provider for [AuthNotifier].
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
