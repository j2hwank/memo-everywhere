// Unit tests for RecordVoice usecase
//
// RED phase: Tests for platform codec selection (REQ-V-006),
// native STT transcription (REQ-V-002, REQ-V-005),
// cloud STT fallback (REQ-V-003), and STT failure recovery (REQ-V-008).

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memo_everywhere/domain/usecases/record_voice.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockNetworkChecker extends Mock implements VoiceNetworkChecker {}

class MockNativeStt extends Mock implements NativeSttService {}

class MockBackendStt extends Mock implements BackendSttService {}

void main() {
  late MockNetworkChecker mockNetwork;
  late MockNativeStt mockNativeStt;
  late MockBackendStt mockBackendStt;
  late RecordVoice usecase;

  setUp(() {
    mockNetwork = MockNetworkChecker();
    mockNativeStt = MockNativeStt();
    mockBackendStt = MockBackendStt();
    usecase = RecordVoice(
      network: mockNetwork,
      nativeStt: mockNativeStt,
      backendStt: mockBackendStt,
      selectedLocale: 'ko-KR',
    );
  });

  // -------------------------------------------------------------------------
  // AC-2: recording stop → native STT called
  // -------------------------------------------------------------------------
  group('RecordVoice.transcribe — native STT path (AC-2)', () {
    test('calls nativeStt.recognize when cloudEnabled is false', () async {
      const audioPath = '/tmp/recording.m4a';
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      when(
        () => mockNativeStt.recognize(audioPath, localeId: any(named: 'localeId')),
      ).thenAnswer((_) async => 'hello world');

      final result = await usecase.transcribe(audioPath, cloudEnabled: false);

      expect(result, equals('hello world'));
      verify(() => mockNativeStt.recognize(audioPath, localeId: 'ko-KR')).called(1);
      verifyNever(() => mockBackendStt.transcribeAudio(any()));
    });

    test('calls nativeStt.recognize when network is offline even if cloudEnabled=true', () async {
      const audioPath = '/tmp/recording.m4a';
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      when(
        () => mockNativeStt.recognize(audioPath, localeId: any(named: 'localeId')),
      ).thenAnswer((_) async => 'offline text');

      final result = await usecase.transcribe(audioPath, cloudEnabled: true);

      expect(result, equals('offline text'));
      verifyNever(() => mockBackendStt.transcribeAudio(any()));
    });
  });

  // -------------------------------------------------------------------------
  // AC-5: localeId passed correctly to STT
  // -------------------------------------------------------------------------
  group('RecordVoice — locale selection (AC-5)', () {
    test('passes ko-KR localeId to native STT when locale is ko-KR', () async {
      const audioPath = '/tmp/rec.m4a';
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      when(
        () => mockNativeStt.recognize(audioPath, localeId: 'ko-KR'),
      ).thenAnswer((_) async => '한국어 텍스트');

      await usecase.transcribe(audioPath, cloudEnabled: false);

      verify(() => mockNativeStt.recognize(audioPath, localeId: 'ko-KR')).called(1);
    });

    test('passes en-US localeId to native STT when locale is en-US', () async {
      final enUsecase = RecordVoice(
        network: mockNetwork,
        nativeStt: mockNativeStt,
        backendStt: mockBackendStt,
        selectedLocale: 'en-US',
      );
      const audioPath = '/tmp/rec.m4a';
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      when(
        () => mockNativeStt.recognize(audioPath, localeId: 'en-US'),
      ).thenAnswer((_) async => 'english text');

      await enUsecase.transcribe(audioPath, cloudEnabled: false);

      verify(() => mockNativeStt.recognize(audioPath, localeId: 'en-US')).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // AC-3: cloud STT fallback called when network+flag both true
  // -------------------------------------------------------------------------
  group('RecordVoice.transcribe — cloud STT fallback (AC-3)', () {
    test('calls backendStt when network=true AND cloudEnabled=true', () async {
      const audioPath = '/tmp/recording.m4a';
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      when(() => mockBackendStt.transcribeAudio(audioPath))
          .thenAnswer((_) async => 'cloud text');

      final result = await usecase.transcribe(audioPath, cloudEnabled: true);

      expect(result, equals('cloud text'));
      verify(() => mockBackendStt.transcribeAudio(audioPath)).called(1);
      verifyNever(() => mockNativeStt.recognize(any(), localeId: any(named: 'localeId')));
    });

    test('falls back to native STT when cloud STT throws', () async {
      const audioPath = '/tmp/recording.m4a';
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => true);
      when(() => mockBackendStt.transcribeAudio(audioPath))
          .thenThrow(Exception('Network error'));
      when(
        () => mockNativeStt.recognize(audioPath, localeId: any(named: 'localeId')),
      ).thenAnswer((_) async => 'native fallback');

      final result = await usecase.transcribe(audioPath, cloudEnabled: true);

      expect(result, equals('native fallback'));
      verify(() => mockNativeStt.recognize(audioPath, localeId: 'ko-KR')).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // AC-8: STT failure — returns empty string, does not throw
  // -------------------------------------------------------------------------
  group('RecordVoice.transcribe — STT failure recovery (AC-8)', () {
    test('returns empty string when native STT throws', () async {
      const audioPath = '/tmp/recording.m4a';
      when(() => mockNetwork.isConnected()).thenAnswer((_) async => false);
      when(
        () => mockNativeStt.recognize(audioPath, localeId: any(named: 'localeId')),
      ).thenThrow(Exception('STT engine unavailable'));

      final result = await usecase.transcribe(audioPath, cloudEnabled: false);

      expect(result, equals(''));
    });
  });

  // -------------------------------------------------------------------------
  // AC-6: platform codec selection
  // -------------------------------------------------------------------------
  group('RecordVoice — platform codec selection (AC-6)', () {
    test('configForPlatform returns wav encoder on Web', () {
      final config = RecordVoice.configForPlatformTest(isWeb: true, isIOS: false, isAndroid: false, isMacOS: false);
      expect(config.encoderName, equals('wav'));
    });

    test('configForPlatform returns aacLc encoder on iOS', () {
      final config = RecordVoice.configForPlatformTest(isWeb: false, isIOS: true, isAndroid: false, isMacOS: false);
      expect(config.encoderName, equals('aacLc'));
    });

    test('configForPlatform returns aacLc encoder on macOS', () {
      final config = RecordVoice.configForPlatformTest(isWeb: false, isIOS: false, isAndroid: false, isMacOS: true);
      expect(config.encoderName, equals('aacLc'));
    });

    test('configForPlatform returns aacLc encoder on Android', () {
      final config = RecordVoice.configForPlatformTest(isWeb: false, isIOS: false, isAndroid: true, isMacOS: false);
      expect(config.encoderName, equals('aacLc'));
    });

    test('configForPlatform returns wav encoder on Windows/Linux (fallback)', () {
      final config = RecordVoice.configForPlatformTest(isWeb: false, isIOS: false, isAndroid: false, isMacOS: false);
      expect(config.encoderName, equals('wav'));
    });
  });
}
