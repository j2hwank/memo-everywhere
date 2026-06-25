import 'package:record/record.dart';

// ---------------------------------------------------------------------------
// Interfaces (injectable for testing)
// ---------------------------------------------------------------------------

/// Network connectivity check abstraction for the voice feature.
abstract interface class VoiceNetworkChecker {
  Future<bool> isConnected();
}

/// Native on-device speech-to-text abstraction (REQ-V-002).
abstract interface class NativeSttService {
  /// Transcribes the audio at [audioPath] using [localeId] (e.g. 'ko-KR').
  Future<String> recognize(String audioPath, {required String localeId});
}

/// Cloud STT via backend Whisper API abstraction (REQ-V-003).
abstract interface class BackendSttService {
  /// POSTs the audio file at [audioPath] to POST /voice/transcribe.
  Future<String> transcribeAudio(String audioPath);
}

// ---------------------------------------------------------------------------
// Value object returned by configForPlatformTest
// ---------------------------------------------------------------------------

/// Minimal codec descriptor used in platform-selection tests.
class PlatformCodecConfig {
  const PlatformCodecConfig({required this.encoderName});

  final String encoderName;
}

// ---------------------------------------------------------------------------
// RecordVoice UseCase
// ---------------------------------------------------------------------------

/// Orchestrates audio recording and STT transcription.
///
/// // @MX:ANCHOR: [AUTO] transcribe() — STT path selection contract.
/// // @MX:REASON: VoiceStateNotifier and tests depend on this method's
/// // behaviour for cloud-vs-native routing and locale passing.
class RecordVoice {
  RecordVoice({
    required VoiceNetworkChecker network,
    required NativeSttService nativeStt,
    required BackendSttService backendStt,
    required String selectedLocale,
  })  : _network = network,
        _nativeStt = nativeStt,
        _backendStt = backendStt,
        _selectedLocale = selectedLocale;

  final VoiceNetworkChecker _network;
  final NativeSttService _nativeStt;
  final BackendSttService _backendStt;
  final String _selectedLocale;

  /// Transcribes [audioPath] to text.
  ///
  /// Path selection (REQ-V-002/003):
  ///   1. If [cloudEnabled] AND online → call backend (Whisper).
  ///   2. On network failure or cloud disabled → native STT.
  ///   3. On any STT failure → return empty string (REQ-V-008).
  ///
  // @MX:WARN: [AUTO] external network + API failure possible here.
  // @MX:REASON: Cloud STT calls POST /voice/transcribe; falls back to native
  // on any exception to preserve offline-first behaviour (REQ-V-008).
  Future<String> transcribe(String audioPath, {required bool cloudEnabled}) async {
    final online = await _network.isConnected();

    if (cloudEnabled && online) {
      try {
        return await _backendStt.transcribeAudio(audioPath);
      } catch (_) {
        // Fall through to native STT
      }
    }

    try {
      return await _nativeStt.recognize(audioPath, localeId: _selectedLocale);
    } catch (_) {
      // REQ-V-008: STT failure → return empty string; caller preserves voiceUrl.
      return '';
    }
  }

  // ---------------------------------------------------------------------------
  // Platform codec selection (REQ-V-006)
  // ---------------------------------------------------------------------------

  /// Returns the [RecordConfig] appropriate for the current platform.
  ///
  // @MX:NOTE: [AUTO] platform codec rationale:
  //   iOS / macOS → AAC in .m4a container (native HW encoder, low latency).
  //   Android     → AAC in .mp4 container (MediaRecorder default).
  //   Web / Win / Linux → WAV (broadest STT compatibility, no container wrapping).
  static RecordConfig configForPlatform({
    required bool isWeb,
    required bool isIOS,
    required bool isAndroid,
    required bool isMacOS,
  }) {
    if (isWeb) return const RecordConfig(encoder: AudioEncoder.wav);
    if (isIOS || isMacOS) return const RecordConfig(encoder: AudioEncoder.aacLc);
    if (isAndroid) return const RecordConfig(encoder: AudioEncoder.aacLc);
    return const RecordConfig(encoder: AudioEncoder.wav); // Windows / Linux
  }

  /// Test-only helper that returns a [PlatformCodecConfig] without needing
  /// the real [RecordConfig] (avoids importing `record` in test files).
  static PlatformCodecConfig configForPlatformTest({
    required bool isWeb,
    required bool isIOS,
    required bool isAndroid,
    required bool isMacOS,
  }) {
    final config = configForPlatform(
      isWeb: isWeb,
      isIOS: isIOS,
      isAndroid: isAndroid,
      isMacOS: isMacOS,
    );
    // Map AudioEncoder enum to string for readable assertions.
    final name = config.encoder == AudioEncoder.wav ? 'wav' : 'aacLc';
    return PlatformCodecConfig(encoderName: name);
  }
}
