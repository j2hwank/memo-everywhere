import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/memo_provider.dart';
import '../state/voice_provider.dart';
import '../widgets/voice_recorder.dart';

/// Voice recording screen (REQ-V-007).
///
/// States and transitions:
///   idle        → record button visible
///   recording   → VoiceRecorder widget (duration + waveform + stop/cancel)
///   transcribing → loading spinner (AC-4)
///   done        → creates memo with transcription, pops (AC-4)
///   error       → error message + manual-edit button (AC-8)
//
// @MX:NOTE: [AUTO] microphone permission is requested inside VoiceStateNotifier
// before recording starts. On denial the notifier emits VoiceError so this
// page can show guidance.
// @MX:NOTE: [AUTO] AC-4 wiring: VoiceDone → MemoNotifier.create() → Navigator.pop()
// so the home list refreshes automatically via memoNotifierProvider invalidation.
class VoiceRecordPage extends ConsumerWidget {
  const VoiceRecordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceStateNotifierProvider);
    final notifier =
        ref.read(voiceStateNotifierProvider.notifier) as VoiceStateNotifier;

    // AC-4: when transcription completes, create a memo and navigate back.
    ref.listen<VoiceState>(voiceStateNotifierProvider, (_, next) async {
      if (next is VoiceDone && context.mounted) {
        final memoNotifier = ref.read(memoNotifierProvider.notifier);
        await memoNotifier.create(content: next.transcription);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('음성 메모')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: _buildBody(context, state, notifier)),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    VoiceState state,
    VoiceStateNotifier notifier,
  ) {
    return switch (state) {
      VoiceIdle() => _IdleView(notifier: notifier),
      final VoiceRecording s => VoiceRecorder(
          state: s,
          onStop: notifier.stopRecording,
          onCancel: notifier.cancel,
        ),
      VoiceTranscribing() => const _TranscribingView(),
      VoiceDone() => const SizedBox.shrink(), // listener handles navigation
      VoiceError(:final voiceUrl, :final message) =>
        _ErrorView(voiceUrl: voiceUrl, message: message),
    };
  }
}

// ---------------------------------------------------------------------------
// Sub-views
// ---------------------------------------------------------------------------

class _IdleView extends StatelessWidget {
  const _IdleView({required this.notifier});
  final VoiceStateNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('버튼을 눌러 녹음을 시작하세요', textAlign: TextAlign.center),
        const SizedBox(height: 32),
        FilledButton.icon(
          key: const Key('voice_record_button'),
          onPressed: notifier.startRecording,
          icon: const Icon(Icons.mic),
          label: const Text('녹음 시작'),
        ),
      ],
    );
  }
}

class _TranscribingView extends StatelessWidget {
  const _TranscribingView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(key: Key('voice_transcribing_indicator')),
        SizedBox(height: 16),
        Text('텍스트 변환 중...'),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.voiceUrl, this.message});
  final String voiceUrl;
  // Non-null when recording could not START (no audio file to recover).
  // Null when transcription failed after a successful recording (AC-8 path).
  final String? message;

  @override
  Widget build(BuildContext context) {
    // Start-failure: show the custom guidance message, no manual-edit button
    // (there is no audio file to edit).
    if (message != null && message!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_off_rounded, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            key: const Key('voice_error_message'),
            message!,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Transcription-failure (AC-8): audio preserved → offer manual editing.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
        const SizedBox(height: 16),
        const Text(
          key: Key('voice_error_message'),
          '음성 변환에 실패했습니다.\n직접 텍스트를 입력해 주세요.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // Navigate to editor with empty content but preserved voiceUrl (AC-8)
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop({'content': '', 'voiceUrl': voiceUrl}),
          child: const Text('직접 입력'),
        ),
      ],
    );
  }
}
