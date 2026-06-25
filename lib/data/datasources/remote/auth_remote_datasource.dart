import 'package:dio/dio.dart';

/// Token pair returned from a successful login or refresh.
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Abstract interface for authentication remote operations.
abstract interface class AuthRemoteDataSource {
  /// Register a new user. Returns the created user's id.
  Future<String> register(String email, String password);

  /// Authenticate user. Returns [TokenPair] on success.
  Future<TokenPair> login(String email, String password);

  /// Exchange a refresh token for a new access token.
  Future<String> refreshToken(String refreshToken);
}

/// Dio-based implementation targeting the FastAPI backend.
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<String> register(String email, String password) async {
    final response = await _dio.post<dynamic>(
      '/auth/register',
      data: <String, dynamic>{'email': email, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    return data['id'] as String;
  }

  @override
  Future<TokenPair> login(String email, String password) async {
    final response = await _dio.post<dynamic>(
      '/auth/login',
      data: <String, dynamic>{'email': email, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    return TokenPair(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }

  @override
  Future<String> refreshToken(String refreshToken) async {
    final response = await _dio.post<dynamic>(
      '/auth/refresh',
      data: <String, dynamic>{'refresh_token': refreshToken},
    );
    final data = response.data as Map<String, dynamic>;
    return data['access_token'] as String;
  }
}
