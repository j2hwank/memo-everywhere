import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:memo_everywhere/domain/usecases/record_voice.dart';

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Thrown by [BackendSttServiceImpl] when no JWT access token is stored.
///
/// The caller (VoiceStateNotifier) should catch this and transition to
/// [VoiceError] to preserve the recorded audio path (REQ-V-008).
// @MX:NOTE: [AUTO] AuthTokenMissingException — login is a prerequisite for
// cloud STT. Token must be written to flutter_secure_storage after login.
class AuthTokenMissingException implements Exception {
  const AuthTokenMissingException();

  @override
  String toString() => 'AuthTokenMissingException: no access token stored';
}

// ---------------------------------------------------------------------------
// SecureTokenStore — abstraction over flutter_secure_storage (testable)
// ---------------------------------------------------------------------------

/// Abstraction for reading and writing JWT tokens in secure storage.
///
// @MX:ANCHOR: [AUTO] SecureTokenStore — auth token boundary
// @MX:REASON: BackendSttServiceImpl, AuthNotifier, TokenRefreshInterceptor,
// and the Dio interceptor all depend on this interface for JWT access;
// fan_in >= 3.
abstract interface class SecureTokenStore {
  /// Returns the stored access token, or null if none is present.
  Future<String?> readAccessToken();

  /// Returns the stored refresh token, or null if none is present.
  Future<String?> readRefreshToken();

  /// Persists both [accessToken] and [refreshToken] to secure storage.
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  });

  /// Persists only the [accessToken], leaving the refresh token unchanged.
  ///
  /// Used by [TokenRefreshInterceptor] after a silent refresh so that the
  /// long-lived refresh token is never unnecessarily overwritten.
  Future<void> writeAccessToken(String accessToken);

  /// Persists the user [email] to secure storage for session restore.
  Future<void> writeEmail(String email);

  /// Returns the stored user email, or null if none is present.
  Future<String?> readEmail();

  /// Removes all stored credentials (tokens + email) from secure storage.
  Future<void> clear();
}

/// Production implementation backed by [FlutterSecureStorage].
class FlutterSecureTokenStore implements SecureTokenStore {
  const FlutterSecureTokenStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _kAccessTokenKey = 'access_token';
  static const _kRefreshTokenKey = 'refresh_token';
  // @MX:NOTE: [AUTO] Email key for session restore — written on login, cleared
  // on logout via clear(). Read by AuthNotifier.restoreSession() at startup.
  static const _kEmailKey = 'user_email';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _kAccessTokenKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshTokenKey);

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessTokenKey, value: accessToken);
    await _storage.write(key: _kRefreshTokenKey, value: refreshToken);
  }

  @override
  Future<void> writeAccessToken(String accessToken) =>
      _storage.write(key: _kAccessTokenKey, value: accessToken);

  @override
  Future<void> writeEmail(String email) =>
      _storage.write(key: _kEmailKey, value: email);

  @override
  Future<String?> readEmail() => _storage.read(key: _kEmailKey);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAccessTokenKey);
    await _storage.delete(key: _kRefreshTokenKey);
    await _storage.delete(key: _kEmailKey);
  }
}

// ---------------------------------------------------------------------------
// BackendSttServiceImpl — Dio-based cloud transcription
// ---------------------------------------------------------------------------

/// Dio-based implementation of [BackendSttService] targeting
/// POST {baseUrl}/voice/transcribe.
///
/// Auth: reads JWT from [SecureTokenStore]; throws [AuthTokenMissingException]
/// when no token is present.
///
// @MX:ANCHOR: [AUTO] transcribeAudio — cloud STT entry point
// @MX:REASON: Called by VoiceStateNotifier (production) and by
// RecordVoice.transcribe (via BackendSttService interface); fan_in >= 3.
// @MX:WARN: [AUTO] reads file from disk and sends raw bytes over network
// @MX:REASON: File may not exist (recorder crashed) or token may be expired;
// callers must handle both IOException and DioException (REQ-V-008).
class BackendSttServiceImpl implements BackendSttService {
  const BackendSttServiceImpl({
    required Dio dio,
    required SecureTokenStore tokenStore,
  })  : _dio = dio,
        _tokenStore = tokenStore;

  final Dio _dio;
  final SecureTokenStore _tokenStore;

  /// Maps a file extension to the appropriate audio MIME type for Whisper.
  static String _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.webm')) return 'audio/webm';
    // Default: AAC in mp4 container (iOS/Android primary codec)
    return 'audio/mp4';
  }

  @override
  Future<String> transcribeAudio(String audioPath) async {
    final token = await _tokenStore.readAccessToken();
    if (token == null) {
      throw const AuthTokenMissingException();
    }

    final bytes = await File(audioPath).readAsBytes();
    final contentType = _contentTypeForPath(audioPath);

    final response = await _dio.post<dynamic>(
      '/voice/transcribe',
      data: bytes,
      options: Options(
        contentType: contentType,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data as Map<String, dynamic>;
    return data['text'] as String;
  }
}
