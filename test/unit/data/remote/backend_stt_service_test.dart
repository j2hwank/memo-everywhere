// Unit tests for BackendSttServiceImpl (SPEC-VOICE-001 REQ-V-003)
//
// Tests define the contract:
//   - POST raw bytes to {baseUrl}/voice/transcribe
//   - Set Content-Type to audio/mp4 for AAC audio
//   - Attach Authorization: Bearer <token> when token is present
//   - Parse {"text": "..."} response
//   - Throw AuthTokenMissingException when no token is stored

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/data/datasources/remote/backend_stt_service.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockDio extends Mock implements Dio {}

class MockSecureTokenStore extends Mock implements SecureTokenStore {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a real temp file with dummy audio bytes for tests that exercise
/// the file-reading code path in BackendSttServiceImpl.
Future<File> _makeTempAudio(String suffix) async {
  final dir = Directory.systemTemp;
  final file = File(
    '${dir.path}/test_audio_${DateTime.now().microsecondsSinceEpoch}$suffix',
  );
  await file.writeAsBytes([0x00, 0x01, 0x02, 0x03]); // dummy bytes
  return file;
}

void main() {
  late MockDio mockDio;
  late MockSecureTokenStore mockTokenStore;
  late BackendSttServiceImpl service;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockDio = MockDio();
    mockTokenStore = MockSecureTokenStore();
    service = BackendSttServiceImpl(
      dio: mockDio,
      tokenStore: mockTokenStore,
    );
  });

  // -------------------------------------------------------------------------
  // REQ-V-003: POST /voice/transcribe — correct URL and body
  // -------------------------------------------------------------------------
  group('BackendSttServiceImpl.transcribeAudio — request contract', () {
    test('POSTs raw bytes to /voice/transcribe', () async {
      final file = await _makeTempAudio('.m4a');
      addTearDown(() => file.deleteSync());

      const token = 'test-jwt-token';

      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => token);

      when(
        () => mockDio.post<dynamic>(
          '/voice/transcribe',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          data: <String, dynamic>{'text': 'hello world'},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/voice/transcribe'),
        ),
      );

      final result = await service.transcribeAudio(file.path);

      expect(result, equals('hello world'));

      final captured = verify(
        () => mockDio.post<dynamic>(
          '/voice/transcribe',
          data: captureAny(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;

      // captured[0] = data (Uint8List), captured[1] = Options
      expect(captured[0], isA<Uint8List>());
      final options = captured[1] as Options;
      expect(options.contentType, equals('audio/mp4'));
    });

    test('attaches Authorization Bearer header when token is present',
        () async {
      final file = await _makeTempAudio('.m4a');
      addTearDown(() => file.deleteSync());

      const token = 'my-jwt-token';

      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => token);

      Options? capturedOptions;
      when(
        () => mockDio.post<dynamic>(
          '/voice/transcribe',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        capturedOptions = invocation.namedArguments[#options] as Options?;
        return Response<dynamic>(
          data: <String, dynamic>{'text': 'transcribed'},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/voice/transcribe'),
        );
      });

      await service.transcribeAudio(file.path);

      expect(
        capturedOptions?.headers?['Authorization'],
        equals('Bearer my-jwt-token'),
      );
    });

    test('throws AuthTokenMissingException when no token is stored', () async {
      final file = await _makeTempAudio('.m4a');
      addTearDown(() => file.deleteSync());

      when(() => mockTokenStore.readAccessToken()).thenAnswer((_) async => null);

      expect(
        () => service.transcribeAudio(file.path),
        throwsA(isA<AuthTokenMissingException>()),
      );
    });

    test('parses {"text": "..."} from response body', () async {
      final file = await _makeTempAudio('.wav');
      addTearDown(() => file.deleteSync());

      const token = 'tok';

      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => token);
      when(
        () => mockDio.post<dynamic>(
          '/voice/transcribe',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          data: <String, dynamic>{'text': '한국어 텍스트'},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/voice/transcribe'),
        ),
      );

      final result = await service.transcribeAudio(file.path);
      expect(result, equals('한국어 텍스트'));
    });

    test('uses audio/wav content-type for .wav files', () async {
      final file = await _makeTempAudio('.wav');
      addTearDown(() => file.deleteSync());

      const token = 'tok';

      when(() => mockTokenStore.readAccessToken())
          .thenAnswer((_) async => token);

      Options? capturedOptions;
      when(
        () => mockDio.post<dynamic>(
          '/voice/transcribe',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        capturedOptions = invocation.namedArguments[#options] as Options?;
        return Response<dynamic>(
          data: <String, dynamic>{'text': 'wav result'},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/voice/transcribe'),
        );
      });

      await service.transcribeAudio(file.path);
      expect(capturedOptions?.contentType, equals('audio/wav'));
    });
  });
}
