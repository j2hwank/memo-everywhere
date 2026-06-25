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

/// Abstraction for reading the JWT access token from secure storage.
///
// @MX:ANCHOR: [AUTO] SecureTokenStore.readAccessToken — auth boundary
// @MX:REASON: BackendSttServiceImpl and future network interceptors both
// depend on this method for JWT retrieval; fan_in >= 3 expected.
abstract interface class SecureTokenStore {
  /// Returns the stored access token, or null if none is present.
  Future<String?> readAccessToken();
}

/// Production implementation backed by [FlutterSecureStorage].
class FlutterSecureTokenStore implements SecureTokenStore {
  const FlutterSecureTokenStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _kAccessTokenKey = 'access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _kAccessTokenKey);
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
