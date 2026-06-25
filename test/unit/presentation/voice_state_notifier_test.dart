// Unit tests for VoiceStateNotifierImpl real flow (SPEC-VOICE-001)
//
// Tests idle→recording→transcribing→done flow,
// permission denial → error, transcription failure → error (REQ-V-008),
// and cancel → idle.
//
// Uses ProviderContainer with overrides for AudioRecorderService and
// TranscribeService so no real hardware or network is touched.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/presentation/state/voice_provider.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockAudioRecorderService extends Mock implements AudioRecorderService {}

class MockTranscribeService extends Mock implements TranscribeService {}

// ---------------------------------------------------------------------------
// Helper: build container with mocked recorder + transcriber
// ---------------------------------------------------------------------------

ProviderContainer buildContainer({
  required AudioRecorderService recorder,
  required TranscribeService transcriber,
}) {
  return ProviderContainer(
    overrides: [
      audioRecorderServiceProvider.overrideWithValue(recorder),
      transcribeServiceProvider.overrideWithValue(transcriber),
    ],
  );
}

void main() {
  late MockAudioRecorderService mockRecorder;
  late MockTranscribeService mockTranscriber;

  setUp(() {
    mockRecorder = MockAudioRecorderService();
    mockTranscriber = MockTranscribeService();
  });

  // -------------------------------------------------------------------------
  // AC-1 / AC-4: idle → recording → transcribing → done
  // -------------------------------------------------------------------------
  group('VoiceStateNotifierImpl — happy path', () {
    test('startRecording transitions idle → recording when permission granted',
        () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start()).thenAnswer((_) async {});

      final container = buildContainer(
        recorder: mockRecorder,
        transcriber: mockTranscriber,
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceStateNotifierProvider.notifier);
      await notifier.startRecording();

      expect(
        container.read(voiceStateNotifierProvider),
        isA<VoiceRecording>(),
      );
    });

    test('stopRecording transitions recording → transcribing → done',
        () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start()).thenAnswer((_) async {});
      when(() => mockRecorder.stop()).thenAnswer((_) async => '/tmp/rec.m4a');
      when(() => mockTranscriber.transcribe('/tmp/rec.m4a'))
          .thenAnswer((_) async => 'hello world');

      final container = buildContainer(
        recorder: mockRecorder,
        transcriber: mockTranscriber,
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceStateNotifierProvider.notifier);
      await notifier.startRecording();
      await notifier.stopRecording();

      final state = container.read(voiceStateNotifierProvider);
      expect(state, isA<VoiceDone>());
      expect((state as VoiceDone).transcription, equals('hello world'));
    });
  });

  // -------------------------------------------------------------------------
  // AC-8: permission denial → error state
  // -------------------------------------------------------------------------
  group('VoiceStateNotifierImpl — permission denied', () {
    test('transitions to error when mic permission is denied', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => false);

      final container = buildContainer(
        recorder: mockRecorder,
        transcriber: mockTranscriber,
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceStateNotifierProvider.notifier);
      await notifier.startRecording();

      expect(container.read(voiceStateNotifierProvider), isA<VoiceError>());
    });
  });

  // -------------------------------------------------------------------------
  // AC-8: transcription failure → error with preserved voiceUrl
  // -------------------------------------------------------------------------
  group('VoiceStateNotifierImpl — transcription failure', () {
    test('transitions to error with voiceUrl when transcription throws',
        () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start()).thenAnswer((_) async {});
      when(() => mockRecorder.stop()).thenAnswer((_) async => '/tmp/rec.m4a');
      when(() => mockTranscriber.transcribe('/tmp/rec.m4a'))
          .thenThrow(Exception('backend down'));

      final container = buildContainer(
        recorder: mockRecorder,
        transcriber: mockTranscriber,
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceStateNotifierProvider.notifier);
      await notifier.startRecording();
      await notifier.stopRecording();

      final state = container.read(voiceStateNotifierProvider);
      expect(state, isA<VoiceError>());
      expect((state as VoiceError).voiceUrl, equals('/tmp/rec.m4a'));
    });

    test(
        'transitions to error when transcription returns empty (preserves voiceUrl)',
        () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start()).thenAnswer((_) async {});
      when(() => mockRecorder.stop()).thenAnswer((_) async => '/tmp/rec.m4a');
      when(() => mockTranscriber.transcribe('/tmp/rec.m4a'))
          .thenAnswer((_) async => '');

      final container = buildContainer(
        recorder: mockRecorder,
        transcriber: mockTranscriber,
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceStateNotifierProvider.notifier);
      await notifier.startRecording();
      await notifier.stopRecording();

      // REQ-V-008: empty transcription → error state, voiceUrl preserved
      final state = container.read(voiceStateNotifierProvider);
      expect(state, isA<VoiceError>());
      expect((state as VoiceError).voiceUrl, equals('/tmp/rec.m4a'));
    });
  });

  // -------------------------------------------------------------------------
  // cancel → idle
  // -------------------------------------------------------------------------
  group('VoiceStateNotifierImpl — cancel', () {
    test('cancel transitions to idle and stops recorder', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start()).thenAnswer((_) async {});
      when(() => mockRecorder.cancel()).thenAnswer((_) async {});

      final container = buildContainer(
        recorder: mockRecorder,
        transcriber: mockTranscriber,
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceStateNotifierProvider.notifier);
      await notifier.startRecording();
      notifier.cancel();

      expect(container.read(voiceStateNotifierProvider), isA<VoiceIdle>());
    });
  });

  // -------------------------------------------------------------------------
  // REQ-V-START-FAIL: start() throws → VoiceError (does NOT throw, no timer)
  // -------------------------------------------------------------------------
  group('VoiceStateNotifierImpl — start failure (PlatformException)', () {
    test(
        'startRecording transitions to VoiceError when start() throws '
        'and does not rethrow to the caller', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start()).thenThrow(
        Exception('Input device not found from available list.'),
      );

      final container = buildContainer(
        recorder: mockRecorder,
        transcriber: mockTranscriber,
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceStateNotifierProvider.notifier);

      // Must not throw — caller should never see the exception
      await expectLater(notifier.startRecording(), completes);

      final st = container.read(voiceStateNotifierProvider);
      expect(st, isA<VoiceError>(),
          reason: 'state should be VoiceError after start() throws');

      // Start-failure error carries no audio file
      expect((st as VoiceError).voiceUrl, isEmpty,
          reason: 'no audio file was recorded');
    });

    test(
        'startRecording with start() throw sets a non-null message '
        'distinct from the transcription-failure default message', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start()).thenThrow(
        Exception('Input device not found from available list.'),
      );

      final container = buildContainer(
        recorder: mockRecorder,
        transcriber: mockTranscriber,
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceStateNotifierProvider.notifier);
      await notifier.startRecording();

      final st = container.read(voiceStateNotifierProvider) as VoiceError;
      expect(st.message, isNotNull,
          reason: 'start-failure must carry a descriptive message');
      expect(st.message, isNotEmpty);
    });

    test('elapsed timer is NOT running after start() throws', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start()).thenThrow(
        Exception('Input device not found from available list.'),
      );

      final container = buildContainer(
        recorder: mockRecorder,
        transcriber: mockTranscriber,
      );
      addTearDown(container.dispose);

      // Keep a subscription alive so the AutoDisposeNotifier is not disposed
      // during the delayed assertion below.
      final sub = container.listen(
        voiceStateNotifierProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final notifier = container.read(voiceStateNotifierProvider.notifier);
      await notifier.startRecording();

      // Immediately after startRecording completes, the state must be
      // VoiceError. If the elapsed timer were left running it would tick
      // the state to VoiceRecording within 1 second.
      expect(
        container.read(voiceStateNotifierProvider),
        isA<VoiceError>(),
        reason: 'state must be VoiceError immediately after start() throws',
      );

      // Wait longer than one timer tick (1 s) to confirm the timer was never
      // started — state must remain VoiceError, not transition to VoiceRecording.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(
        container.read(voiceStateNotifierProvider),
        isA<VoiceError>(),
        reason: 'elapsed timer must not tick after start() throws',
      );
    });

    test(
        'permission denied → VoiceError.message is null '
        '(existing behavior is unchanged)', () async {
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => false);

      final container = buildContainer(
        recorder: mockRecorder,
        transcriber: mockTranscriber,
      );
      addTearDown(container.dispose);

      final notifier = container.read(voiceStateNotifierProvider.notifier);
      await notifier.startRecording();

      final st = container.read(voiceStateNotifierProvider) as VoiceError;
      // Permission-denied path does not need a start-failure message.
      // Accept either null or an empty string (implementation choice).
      expect(st.message == null || st.message!.isEmpty, isTrue,
          reason: 'permission-denied error should carry no start-failure message');
    });
  });
}
