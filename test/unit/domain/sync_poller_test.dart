// Tests for SyncPoller — the extracted periodic polling unit (T-POLL-*).
//
// SyncPoller wraps Timer.periodic and delegates to a callback on each tick.
// It is deliberately thin so that _HomePageState can hold it, call
// start()/stop() on lifecycle events, and dispose() on widget disposal.
//
// Tests use a FakeSyncCallback counter instead of fake_async so that no
// additional dependency is required. The timer interval is injected via
// constructor so tests can use Duration.zero for immediate ticks without
// waiting 30 real seconds.

import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/core/services/sync_poller.dart';

void main() {
  group('T-POLL-001: SyncPoller start/stop contract', () {
    test('callback is not invoked before start() is called', () async {
      var callCount = 0;
      final poller = SyncPoller(
        interval: const Duration(milliseconds: 10),
        onTick: () async => callCount++,
      );
      // Wait longer than the interval without starting
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(callCount, equals(0));
      poller.dispose();
    });

    test('callback is invoked on each tick after start()', () async {
      final calls = <int>[];
      final poller = SyncPoller(
        interval: const Duration(milliseconds: 20),
        onTick: () async => calls.add(calls.length),
      );

      poller.start();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      poller.stop();

      // At least 2 ticks should have fired in 70ms with a 20ms interval.
      expect(calls.length, greaterThanOrEqualTo(2));
      poller.dispose();
    });

    test('stop() cancels the timer so no more callbacks fire', () async {
      var callCount = 0;
      final poller = SyncPoller(
        interval: const Duration(milliseconds: 20),
        onTick: () async => callCount++,
      );

      poller.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      poller.stop();

      final countAfterStop = callCount;
      // Wait another interval period — no new calls should happen.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(callCount, equals(countAfterStop));
      poller.dispose();
    });

    test('calling stop() before start() is a no-op (no exception)', () {
      final poller = SyncPoller(
        interval: const Duration(milliseconds: 20),
        onTick: () async {},
      );
      expect(() => poller.stop(), returnsNormally);
      poller.dispose();
    });

    test('dispose() stops polling and cleans up', () async {
      var callCount = 0;
      final poller = SyncPoller(
        interval: const Duration(milliseconds: 20),
        onTick: () async => callCount++,
      );

      poller.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      poller.dispose();

      final countAtDispose = callCount;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(callCount, equals(countAtDispose));
    });
  });

  group('T-POLL-002: start() does not create duplicate timers', () {
    test('calling start() twice only runs one timer (no double-firing)', () async {
      var callCount = 0;
      final poller = SyncPoller(
        interval: const Duration(milliseconds: 20),
        onTick: () async => callCount++,
      );

      poller.start();
      poller.start(); // second call should cancel first and restart (or be a no-op)
      await Future<void>.delayed(const Duration(milliseconds: 70));
      poller.stop();

      // The rate should be consistent with a single timer (not doubled).
      // With a 20ms interval and 70ms window: expect at most 4 ticks (not 8+).
      expect(callCount, lessThanOrEqualTo(5));
      poller.dispose();
    });
  });

  group('T-POLL-003: restart semantics (stop then start)', () {
    test('stop() then start() resumes polling', () async {
      var callCount = 0;
      final poller = SyncPoller(
        interval: const Duration(milliseconds: 20),
        onTick: () async => callCount++,
      );

      poller.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      poller.stop();

      final countAfterFirstStop = callCount;

      // Simulate returning to foreground
      poller.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      poller.stop();

      // More ticks should have been added after re-start
      expect(callCount, greaterThan(countAfterFirstStop));
      poller.dispose();
    });
  });
}
