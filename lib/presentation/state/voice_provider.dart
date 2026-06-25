import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// VoiceState — sealed union
// ---------------------------------------------------------------------------

/// Represents the recording / transcription lifecycle.
///
/// States: idle → recording → transcribing → done | error
sealed class VoiceState {
  const VoiceState();

  const factory VoiceState.idle() = VoiceIdle;

  const factory VoiceState.recording({
    required Duration elapsed,
    required double amplitude,
  }) = VoiceRecording;

  const factory VoiceState.transcribing() = VoiceTranscribing;

  const factory VoiceState.done({required String transcription}) = VoiceDone;

  const factory VoiceState.error({required String voiceUrl}) = VoiceError;
}

class VoiceIdle extends VoiceState {
  const VoiceIdle();
}

class VoiceRecording extends VoiceState {
  const VoiceRecording({required this.elapsed, required this.amplitude});
  final Duration elapsed;
  final double amplitude;
}

class VoiceTranscribing extends VoiceState {
  const VoiceTranscribing();
}

class VoiceDone extends VoiceState {
  const VoiceDone({required this.transcription});
  final String transcription;
}

class VoiceError extends VoiceState {
  const VoiceError({required this.voiceUrl});
  final String voiceUrl;
}

// ---------------------------------------------------------------------------
// VoiceStateNotifier interface + stub provider
// ---------------------------------------------------------------------------

/// Interface that both the real notifier and test fakes implement.
abstract interface class VoiceStateNotifier {
  Future<void> startRecording();
  Future<void> stopRecording();
  void cancel();
}

/// Riverpod provider for the voice recording state.
///
/// // @MX:NOTE: [AUTO] overrideWith() in tests replaces this with FakeVoiceNotifier.
final voiceStateNotifierProvider =
    AutoDisposeNotifierProvider<VoiceStateNotifierImpl, VoiceState>(
  VoiceStateNotifierImpl.new,
);

/// Default implementation used at runtime.
///
/// In production this would inject real AudioRecorder + SpeechToText.
/// For now it delegates to a no-op stub so the UI can be tested
/// and replaced in Phase 3/4 with real hardware.
class VoiceStateNotifierImpl extends AutoDisposeNotifier<VoiceState>
    implements VoiceStateNotifier {
  @override
  VoiceState build() => const VoiceState.idle();

  @override
  Future<void> startRecording() async {
    state = const VoiceState.recording(elapsed: Duration.zero, amplitude: 0.0);
  }

  @override
  Future<void> stopRecording() async {
    state = const VoiceState.transcribing();
    // Real implementation: await recorder.stop() → transcribe → navigate
    // Stubbed: transition to done immediately.
    state = const VoiceState.done(transcription: '');
  }

  @override
  void cancel() {
    state = const VoiceState.idle();
  }
}
