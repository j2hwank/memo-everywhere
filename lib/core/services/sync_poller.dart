import 'dart:async';

// @MX:NOTE: [AUTO] SyncPoller — thin wrapper around Timer.periodic that manages
// the foreground polling lifecycle for cross-device sync.
// @MX:WARN: [AUTO] Timer.periodic MUST be cancelled on stop()/dispose() to avoid
// callback fires after the widget is unmounted. Always call dispose() in State.dispose().
// @MX:REASON: Leaked timers call syncNow() on a disposed ProviderRef, causing
// "ProviderRef was used after being disposed" StateError in production.

/// Manages a repeating timer that fires [onTick] on every [interval].
///
/// Lifecycle:
/// - [start] — (re)starts the timer; cancels any existing timer first.
/// - [stop]  — cancels the timer; does nothing if already stopped.
/// - [dispose] — permanent shutdown; same as [stop]. Safe to call multiple times.
///
/// The [interval] is injected so that tests can pass tiny durations without
/// waiting 30 real seconds. Production code uses [SyncPoller.defaultInterval].
class SyncPoller {
  /// Default polling interval for cross-device sync (30 seconds).
  ///
  /// To change the interval, update this constant. The widget reads it
  /// at init time so a hot restart is sufficient in development.
  static const defaultInterval = Duration(seconds: 30);

  SyncPoller({
    required this.interval,
    required this.onTick,
  });

  /// Interval between ticks. Defaults to [defaultInterval] in production.
  final Duration interval;

  /// Called on every tick. Must be idempotent and best-effort (never throw).
  final Future<void> Function() onTick;

  Timer? _timer;

  /// Starts (or restarts) the periodic timer.
  ///
  /// If a timer is already running, it is cancelled first to prevent
  /// duplicate timers from stacking up (e.g., multiple lifecycle resumes).
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  /// Stops the timer. Safe to call when not running.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Permanently stops the timer and releases resources.
  ///
  /// Must be called in [State.dispose] to prevent memory leaks.
  void dispose() {
    stop();
  }
}
