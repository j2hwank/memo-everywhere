// Widget tests for VoiceRecordPage (REQ-V-007, REQ-V-001, REQ-V-004)
//
// RED phase: Tests define the UI contract before implementation exists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/presentation/pages/voice_record_page.dart';
import 'package:memo_everywhere/presentation/state/voice_provider.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget buildVoiceRecordPage({
  required VoiceStateNotifierImpl notifier,
}) {
  return ProviderScope(
    overrides: [
      voiceStateNotifierProvider.overrideWith(() => notifier),
    ],
    child: const MaterialApp(
      home: VoiceRecordPage(),
    ),
  );
}

// Fake notifier that does not touch real audio hardware.
class FakeVoiceNotifier extends VoiceStateNotifierImpl {
  bool startRecordingCalled = false;
  bool stopRecordingCalled = false;
  bool cancelCalled = false;

  @override
  VoiceState build() => const VoiceState.idle();

  @override
  Future<void> startRecording() async {
    startRecordingCalled = true;
    state = const VoiceState.recording(elapsed: Duration.zero, amplitude: 0.0);
  }

  @override
  Future<void> stopRecording() async {
    stopRecordingCalled = true;
    state = const VoiceState.transcribing();
  }

  @override
  void cancel() {
    cancelCalled = true;
    state = const VoiceState.idle();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('VoiceRecordPage — AC-7: shows duration, waveform, stop/cancel', () {
    testWidgets('shows record button in idle state', (tester) async {
      final notifier = FakeVoiceNotifier();
      await tester.pumpWidget(buildVoiceRecordPage(notifier: notifier));
      await tester.pump();

      // Record button must be present
      expect(find.byKey(const Key('voice_record_button')), findsOneWidget);
    });

    testWidgets('shows elapsed duration text when recording', (tester) async {
      final notifier = FakeVoiceNotifier();
      await tester.pumpWidget(buildVoiceRecordPage(notifier: notifier));

      // Trigger recording state
      await tester.tap(find.byKey(const Key('voice_record_button')));
      await tester.pump();

      // Duration text should be displayed (e.g. "0:00")
      expect(find.byKey(const Key('voice_elapsed_duration')), findsOneWidget);
    });

    testWidgets('shows waveform widget when recording', (tester) async {
      final notifier = FakeVoiceNotifier();
      await tester.pumpWidget(buildVoiceRecordPage(notifier: notifier));

      await tester.tap(find.byKey(const Key('voice_record_button')));
      await tester.pump();

      expect(find.byKey(const Key('voice_waveform')), findsOneWidget);
    });

    testWidgets('shows stop button when recording', (tester) async {
      final notifier = FakeVoiceNotifier();
      await tester.pumpWidget(buildVoiceRecordPage(notifier: notifier));

      await tester.tap(find.byKey(const Key('voice_record_button')));
      await tester.pump();

      expect(find.byKey(const Key('voice_stop_button')), findsOneWidget);
    });

    testWidgets('shows cancel button when recording', (tester) async {
      final notifier = FakeVoiceNotifier();
      await tester.pumpWidget(buildVoiceRecordPage(notifier: notifier));

      await tester.tap(find.byKey(const Key('voice_record_button')));
      await tester.pump();

      expect(find.byKey(const Key('voice_cancel_button')), findsOneWidget);
    });
  });

  group('VoiceRecordPage — AC-1: record button starts recording', () {
    testWidgets('tapping record button calls startRecording', (tester) async {
      final notifier = FakeVoiceNotifier();
      await tester.pumpWidget(buildVoiceRecordPage(notifier: notifier));
      await tester.pump();

      await tester.tap(find.byKey(const Key('voice_record_button')));
      await tester.pump();

      expect(notifier.startRecordingCalled, isTrue);
    });

    testWidgets('tapping stop button calls stopRecording', (tester) async {
      final notifier = FakeVoiceNotifier();
      await tester.pumpWidget(buildVoiceRecordPage(notifier: notifier));

      // Enter recording state first
      await tester.tap(find.byKey(const Key('voice_record_button')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('voice_stop_button')));
      await tester.pump();

      expect(notifier.stopRecordingCalled, isTrue);
    });

    testWidgets('tapping cancel button calls cancel', (tester) async {
      final notifier = FakeVoiceNotifier();
      await tester.pumpWidget(buildVoiceRecordPage(notifier: notifier));

      await tester.tap(find.byKey(const Key('voice_record_button')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('voice_cancel_button')));
      await tester.pump();

      expect(notifier.cancelCalled, isTrue);
    });
  });

  group('VoiceRecordPage — AC-4: transcribed text pre-fills content', () {
    testWidgets('shows transcribing spinner during transcribing state', (tester) async {
      final notifier = FakeVoiceNotifier();
      await tester.pumpWidget(buildVoiceRecordPage(notifier: notifier));

      // Manually set transcribing state
      notifier.state = const VoiceState.transcribing();
      await tester.pump();

      expect(find.byKey(const Key('voice_transcribing_indicator')), findsOneWidget);
    });
  });

  group('VoiceRecordPage — AC-8: STT failure shows error state', () {
    testWidgets('shows error message when STT fails', (tester) async {
      final notifier = FakeVoiceNotifier();
      await tester.pumpWidget(buildVoiceRecordPage(notifier: notifier));

      notifier.state = const VoiceState.error(voiceUrl: '/tmp/rec.m4a');
      await tester.pump();

      expect(find.byKey(const Key('voice_error_message')), findsOneWidget);
    });
  });
}
