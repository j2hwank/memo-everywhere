// Widget tests for voice transcription → memo creation wiring (SPEC-VOICE-001 AC-4)
//
// When VoiceRecordPage receives VoiceDone, it must call MemoNotifier.create()
// with the transcribed text as content.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/presentation/pages/voice_record_page.dart';
import 'package:memo_everywhere/presentation/state/memo_provider.dart';
import 'package:memo_everywhere/presentation/state/voice_provider.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Fake notifier that immediately emits VoiceDone on stopRecording().
class FakeVoiceNotifierDone extends VoiceStateNotifierImpl {
  @override
  VoiceState build() => const VoiceState.idle();

  @override
  Future<void> startRecording() async {
    state = const VoiceState.recording(elapsed: Duration.zero, amplitude: 0.0);
  }

  @override
  Future<void> stopRecording() async {
    state = const VoiceState.transcribing();
    state = const VoiceState.done(transcription: '음성 메모 내용입니다');
  }

  @override
  void cancel() => state = const VoiceState.idle();
}

/// Capturing notifier that records create() calls without hitting real storage.
class CapturingMemoNotifier extends MemoNotifier {
  final List<({String? title, String content})> calls = [];

  @override
  void build() {}

  @override
  Future<void> create({String? title, required String content}) async {
    calls.add((title: title, content: content));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // AC-4: VoiceDone → MemoNotifier.create() is called with transcription
  // -------------------------------------------------------------------------
  group('VoiceRecordPage — AC-4: voice done creates memo', () {
    testWidgets('creates memo when VoiceDone state is emitted', (tester) async {
      final voiceNotifier = FakeVoiceNotifierDone();
      final memoCapture = CapturingMemoNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceStateNotifierProvider.overrideWith(() => voiceNotifier),
            memoNotifierProvider.overrideWith(() => memoCapture),
          ],
          child: const MaterialApp(
            home: VoiceRecordPage(),
          ),
        ),
      );
      await tester.pump();

      // Tap record button → recording state
      await tester.tap(find.byKey(const Key('voice_record_button')));
      await tester.pump();

      // Tap stop → triggers done state → listener creates memo
      await tester.tap(find.byKey(const Key('voice_stop_button')));
      await tester.pumpAndSettle();

      // MemoNotifier.create() must have been called with the transcription
      expect(memoCapture.calls, hasLength(1));
      expect(memoCapture.calls.first.content, equals('음성 메모 내용입니다'));
    });

    testWidgets('does not create memo when cancel is called', (tester) async {
      final voiceNotifier = FakeVoiceNotifierDone();
      final memoCapture = CapturingMemoNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceStateNotifierProvider.overrideWith(() => voiceNotifier),
            memoNotifierProvider.overrideWith(() => memoCapture),
          ],
          child: const MaterialApp(
            home: VoiceRecordPage(),
          ),
        ),
      );
      await tester.pump();

      // Start recording
      await tester.tap(find.byKey(const Key('voice_record_button')));
      await tester.pump();

      // Cancel instead of stop
      await tester.tap(find.byKey(const Key('voice_cancel_button')));
      await tester.pump();

      // No memo should be created
      expect(memoCapture.calls, isEmpty);
    });
  });
}
