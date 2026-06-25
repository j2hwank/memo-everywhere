import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/network/dio_config.dart';
import '../../data/datasources/remote/backend_stt_service.dart';
import '../../domain/usecases/record_voice.dart';

// ---------------------------------------------------------------------------
// VoiceState — sealed union (UNCHANGED interface)
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

  // @MX:NOTE: [AUTO] message is null for transcription-failure (audio preserved);
  // non-null for start-failure (no audio, user needs hardware guidance).
  const factory VoiceState.error({
    required String voiceUrl,
    String? message,
  }) = VoiceError;
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
  const VoiceError({required this.voiceUrl, this.message});
  final String voiceUrl;
  // Non-null when recording could not START (no audio file to recover).
  // Null when transcription failed after a successful recording (audio preserved).
  final String? message;
}

// ---------------------------------------------------------------------------
// Abstractions injected into VoiceStateNotifierImpl (testable seams)
// ---------------------------------------------------------------------------

/// Abstraction over [AudioRecorder] for testability.
///
// @MX:ANCHOR: [AUTO] AudioRecorderService — recording hardware boundary
// @MX:REASON: VoiceStateNotifierImpl and tests both depend on this interface;
// fan_in >= 3 across production + test doubles.
abstract interface class AudioRecorderService {
  /// Returns true if microphone permission is granted.
  Future<bool> hasPermission();

  /// Starts recording to a temporary file.
  Future<void> start();

  /// Stops recording and returns the path of the saved audio file.
  Future<String?> stop();

  /// Cancels the current recording and deletes the temporary file.
  Future<void> cancel();
}

/// Abstraction over the transcription call (cloud or local).
///
// @MX:NOTE: [AUTO] TranscribeService wraps BackendSttService so that
// VoiceStateNotifierImpl does not depend on Dio directly — stays testable.
abstract interface class TranscribeService {
  Future<String> transcribe(String audioPath);
}

// ---------------------------------------------------------------------------
// Production implementations
// ---------------------------------------------------------------------------

/// [AudioRecorderService] backed by the `record` package [AudioRecorder].
//
// @MX:WARN: [AUTO] uses platform microphone hardware
// @MX:REASON: Requires RECORD_AUDIO (Android) / NSMicrophoneUsageDescription
// (iOS) permissions declared in manifests. On denial hasPermission() returns
// false and the notifier transitions to VoiceError.
class RecordPackageAudioService implements AudioRecorderService {
  RecordPackageAudioService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  String? _tempPath;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    _tempPath = '${dir.path}/voice_memo_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final config = RecordVoice.configForPlatform(
      isWeb: false,
      isIOS: Platform.isIOS,
      isAndroid: Platform.isAndroid,
      isMacOS: Platform.isMacOS,
    );
    await _recorder.start(config, path: _tempPath!);
  }

  @override
  Future<String?> stop() async {
    final path = await _recorder.stop();
    _tempPath = null;
    return path;
  }

  @override
  Future<void> cancel() async {
    await _recorder.cancel();
    _tempPath = null;
  }
}

/// [TranscribeService] backed by [BackendSttServiceImpl].
class BackendTranscribeService implements TranscribeService {
  const BackendTranscribeService({required BackendSttService backendStt})
      : _backendStt = backendStt;

  final BackendSttService _backendStt;

  @override
  Future<String> transcribe(String audioPath) =>
      _backendStt.transcribeAudio(audioPath);
}

// ---------------------------------------------------------------------------
// VoiceStateNotifier interface (unchanged — widget layer depends on this)
// ---------------------------------------------------------------------------

/// Interface that both the real notifier and test fakes implement.
abstract interface class VoiceStateNotifier {
  Future<void> startRecording();
  Future<void> stopRecording();
  void cancel();
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Provider for the [BackendSttService] used in production.
final backendSttServiceProvider = Provider<BackendSttService>((ref) {
  final dio = ref.watch(dioProvider);
  final tokenStore = ref.watch(secureTokenStoreProvider);
  return BackendSttServiceImpl(dio: dio, tokenStore: tokenStore);
});

/// Provider for [TranscribeService].
final transcribeServiceProvider = Provider<TranscribeService>((ref) {
  final stt = ref.watch(backendSttServiceProvider);
  return BackendTranscribeService(backendStt: stt);
});

/// Provider for [AudioRecorderService].
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  return RecordPackageAudioService();
});

/// Riverpod provider for the voice recording state.
///
// @MX:NOTE: [AUTO] overrideWith() in tests replaces this with FakeVoiceNotifier.
// @MX:NOTE: [AUTO] audioRecorderServiceProvider and transcribeServiceProvider
// are overridable in tests to avoid real hardware and network calls.
final voiceStateNotifierProvider =
    AutoDisposeNotifierProvider<VoiceStateNotifierImpl, VoiceState>(
  VoiceStateNotifierImpl.new,
);

// ---------------------------------------------------------------------------
// VoiceStateNotifierImpl — REAL implementation
// ---------------------------------------------------------------------------

/// Real notifier: AudioRecorder → BackendSttService → memo creation.
///
// @MX:ANCHOR: [AUTO] VoiceStateNotifierImpl — recording lifecycle controller
// @MX:REASON: VoiceRecordPage, widget tests, and unit tests all depend on
// this class's public build/startRecording/stopRecording/cancel interface.
// @MX:WARN: [AUTO] manages async recording timer and amplitude polling
// @MX:REASON: Timer.periodic is used for elapsed duration ticks; must be
// cancelled in cancel() and after stop() to avoid state-after-dispose errors.
class VoiceStateNotifierImpl extends AutoDisposeNotifier<VoiceState>
    implements VoiceStateNotifier {
  // Dependencies resolved in build() from the Riverpod container.
  // Overridable in tests via audioRecorderServiceProvider /
  // transcribeServiceProvider overrides in ProviderContainer.
  late AudioRecorderService _recorderService;
  late TranscribeService _transcriberService;

  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  VoiceState build() {
    // Resolve production dependencies from the Riverpod container.
    _recorderService = ref.read(audioRecorderServiceProvider);
    _transcriberService = ref.read(transcribeServiceProvider);
    return const VoiceState.idle();
  }

  // @MX:WARN: [AUTO] wraps hasPermission + start() in try/catch
  // @MX:REASON: PlatformException from the native record layer must never
  // propagate to the caller; on any failure the notifier transitions to
  // VoiceError so the UI can guide the user.
  @override
  Future<void> startRecording() async {
    try {
      final granted = await _recorderService.hasPermission();
      if (!granted) {
        state = const VoiceState.error(voiceUrl: '');
        return;
      }

      await _recorderService.start();
    } catch (_) {
      // Recording could not start (no mic, device busy, permission denied at
      // native layer, etc.). Cancel the elapsed timer if it was somehow
      // started, then surface the error with a user-facing message.
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      state = const VoiceState.error(
        voiceUrl: '',
        message: '녹음을 시작할 수 없습니다. 마이크를 확인해 주세요.',
      );
      return;
    }

    _elapsed = Duration.zero;
    _startElapsedTimer();
    state = VoiceState.recording(elapsed: _elapsed, amplitude: 0.0);
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      // Only update if still recording
      if (state is VoiceRecording) {
        state = VoiceState.recording(elapsed: _elapsed, amplitude: 0.0);
      }
    });
  }

  @override
  Future<void> stopRecording() async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    state = const VoiceState.transcribing();

    String? audioPath;
    try {
      audioPath = await _recorderService.stop();
    } catch (e) {
      state = VoiceState.error(voiceUrl: audioPath ?? '');
      return;
    }

    if (audioPath == null || audioPath.isEmpty) {
      state = const VoiceState.error(voiceUrl: '');
      return;
    }

    try {
      final text = await _transcriberService.transcribe(audioPath);
      if (text.isEmpty) {
        // REQ-V-008: empty transcription preserves voiceUrl for manual editing
        state = VoiceState.error(voiceUrl: audioPath);
        return;
      }
      state = VoiceState.done(transcription: text);
    } catch (_) {
      // REQ-V-008: transcription failure → preserve voiceUrl
      state = VoiceState.error(voiceUrl: audioPath);
    }
  }

  @override
  void cancel() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _recorderService.cancel();
    state = const VoiceState.idle();
  }
}
