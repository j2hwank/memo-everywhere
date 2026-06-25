import 'package:flutter/material.dart';
import '../state/voice_provider.dart';

/// Waveform visualization and recording controls widget (REQ-V-007).
///
/// Displays the elapsed duration, a placeholder waveform, and stop/cancel buttons.
/// Driven entirely by [state] passed from VoiceRecordPage.
class VoiceRecorder extends StatelessWidget {
  const VoiceRecorder({
    super.key,
    required this.state,
    required this.onStop,
    required this.onCancel,
  });

  final VoiceRecording state;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Elapsed duration (AC-7)
        Text(
          _formatDuration(state.elapsed),
          key: const Key('voice_elapsed_duration'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        // Waveform placeholder (AC-7)
        Container(
          key: const Key('voice_waveform'),
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: _WaveformPainter(amplitude: state.amplitude),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Cancel button (AC-7)
            OutlinedButton.icon(
              key: const Key('voice_cancel_button'),
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              label: const Text('취소'),
            ),
            // Stop button (AC-7)
            FilledButton.icon(
              key: const Key('voice_stop_button'),
              onPressed: onStop,
              icon: const Icon(Icons.stop),
              label: const Text('완료'),
            ),
          ],
        ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.amplitude});

  final double amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withAlpha(180)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const barCount = 30;
    final barWidth = size.width / barCount;
    for (var i = 0; i < barCount; i++) {
      final barHeight = (size.height * 0.2) +
          (size.height * 0.6) * ((amplitude * 0.7) + (i % 5) * 0.06);
      final x = i * barWidth + barWidth / 2;
      final top = (size.height - barHeight) / 2;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.amplitude != amplitude;
}
