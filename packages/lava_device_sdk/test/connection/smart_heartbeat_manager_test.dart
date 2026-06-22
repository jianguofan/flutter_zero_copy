import 'dart:async';
import 'package:lava_device_sdk/lava_device_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('SmartHeartbeatManager — heartbeat sending', () {
    test('sends heartbeat when idle exceeds threshold', () async {
      int heartbeatCount = 0;
      final hb = SmartHeartbeatManager(
        idleThreshold: const Duration(milliseconds: 50),
        checkInterval: const Duration(milliseconds: 20),
        onSendHeartbeat: () async {
          heartbeatCount++;
          return const HeartbeatResult(success: true);
        },
      );

      hb.start();
      hb.recordCommunication();

      // Wait for idleThreshold + checkInterval to pass
      await Future.delayed(const Duration(milliseconds: 150));

      hb.stop();
      expect(heartbeatCount, greaterThan(0));
    });

    test('does not heartbeat when actively communicating', () async {
      int heartbeatCount = 0;
      final hb = SmartHeartbeatManager(
        idleThreshold: const Duration(seconds: 30),
        checkInterval: const Duration(milliseconds: 50),
        onSendHeartbeat: () async {
          heartbeatCount++;
          return const HeartbeatResult(success: true);
        },
      );

      hb.start();

      for (int i = 0; i < 5; i++) {
        hb.recordCommunication();
        await Future.delayed(const Duration(milliseconds: 30));
      }

      hb.stop();
      expect(heartbeatCount, 0);
    });

    test('recordCommunication resets idle timer', () async {
      int heartbeatCount = 0;
      final hb = SmartHeartbeatManager(
        idleThreshold: const Duration(milliseconds: 100),
        checkInterval: const Duration(milliseconds: 40),
        onSendHeartbeat: () async {
          heartbeatCount++;
          return const HeartbeatResult(success: true);
        },
      );

      hb.start();

      hb.recordCommunication();
      await Future.delayed(const Duration(milliseconds: 60));
      hb.recordCommunication(); // Reset
      await Future.delayed(const Duration(milliseconds: 60));
      hb.recordCommunication(); // Reset again

      hb.stop();
      expect(heartbeatCount, 0);
    });
  });

  group('SmartHeartbeatManager — state streaming', () {
    test('emits initial state on start', () async {
      final hb = SmartHeartbeatManager(
        onSendHeartbeat: () async => const HeartbeatResult(success: true),
      );

      HeartbeatState? lastState;
      hb.stateStream.listen((s) => lastState = s);

      hb.start();
      await Future.delayed(const Duration(milliseconds: 10));

      expect(lastState, isNotNull);
      expect(lastState!.active, true);

      hb.stop();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(lastState!.active, false);

      hb.dispose();
    });

    test('tracks failCount', () async {
      final hb = SmartHeartbeatManager(
        idleThreshold: const Duration(milliseconds: 30),
        checkInterval: const Duration(milliseconds: 20),
        maxHeartbeatFailures: 3,
        onSendHeartbeat: () async => const HeartbeatResult(success: false),
      );

      hb.start();

      // Wait for a few heartbeat cycles
      await Future.delayed(const Duration(milliseconds: 150));

      expect(hb.currentState.failCount, greaterThan(0));
      hb.stop();
      hb.dispose();
    });

    test('resets failCount on successful heartbeat', () async {
      // First fail, then succeed
      bool shouldFail = true;
      final hb = SmartHeartbeatManager(
        idleThreshold: const Duration(milliseconds: 30),
        checkInterval: const Duration(milliseconds: 20),
        onSendHeartbeat: () async {
          if (shouldFail) {
            shouldFail = false;
            return const HeartbeatResult(success: false);
          }
          return const HeartbeatResult(success: true);
        },
      );

      hb.start();

      // First heartbeat fires immediately (no _lastCommunicationTime)
      // After it fails, it sets _lastCommunicationTime
      // Next check at 20ms: idle=20ms < 30ms → skip
      // Check at 40ms: idle=40ms > 30ms → send (success)
      // So failCount peaks at 1 and then resets
      await Future.delayed(const Duration(milliseconds: 50));

      // At this point, the first (failed) heartbeat has fired, maybe the second too
      // The key assertion: eventually failCount returns to 0
      await Future.delayed(const Duration(milliseconds: 100));
      expect(hb.currentState.failCount, 0);

      hb.stop();
      hb.dispose();
    });
  });

  group('SmartHeartbeatManager — health evaluation', () {
    test('default state is unreachable (MQTT offline assumed)', () {
      final hb = SmartHeartbeatManager(
        onSendHeartbeat: () async => const HeartbeatResult(success: true),
      );
      expect(hb.health, DeviceHealth.unreachable);
      expect(hb.lastReason, HealthChangeReason.unknown);
      hb.dispose();
    });

    test('transitions to healthy when MQTT online + heartbeat success', () async {
      final completer = Completer<HealthChangeEvent>();
      final hb = SmartHeartbeatManager(
        idleThreshold: const Duration(milliseconds: 30),
        checkInterval: const Duration(milliseconds: 20),
        onSendHeartbeat: () async {
          return const HeartbeatResult(success: true);
        },
      );

      hb.healthStream.listen((event) {
        if (event.health == DeviceHealth.healthy &&
            !completer.isCompleted) {
          completer.complete(event);
        }
      });

      hb.start();
      hb.onMqttOnline(); // Mark MQTT as alive

      final event = await completer.future
          .timeout(const Duration(seconds: 2));

      expect(event.health, DeviceHealth.healthy);
      hb.stop();
      hb.dispose();
    });

    test('transitions to unreachable when MQTT goes offline', () async {
      final hb = SmartHeartbeatManager(
        onSendHeartbeat: () async => const HeartbeatResult(success: true),
      );

      // Set up healthy state first
      hb.start();
      hb.onMqttOnline();
      // Simulate a successful heartbeat response
      // MQTT online + no failures → healthy after evaluation
      // (but we need an actual heartbeat to trigger health evaluation)
      hb.stop();

      // Now test offline transition
      hb.onMqttOffline();
      expect(hb.health, DeviceHealth.unreachable);
      expect(hb.lastReason, HealthChangeReason.mqttDisconnected);

      hb.dispose();
    });

    test('transitions to degraded after maxHeartbeatFailures', () async {
      // First succeed once to establish a healthy baseline, then fail repeatedly
      int callCount = 0;
      final hb = SmartHeartbeatManager(
        idleThreshold: const Duration(milliseconds: 20),
        checkInterval: const Duration(milliseconds: 10),
        maxHeartbeatFailures: 2,
        onSendHeartbeat: () async {
          callCount++;
          // First heartbeat succeeds (establishes baseline), rest fail
          if (callCount == 1) {
            return const HeartbeatResult(success: true);
          }
          return const HeartbeatResult(success: false);
        },
      );

      final events = <HealthChangeEvent>[];
      hb.healthStream.listen(events.add);

      hb.start();
      hb.onMqttOnline(); // MQTT is alive

      // Wait for enough heartbeat cycles
      await Future.delayed(const Duration(milliseconds: 300));

      // Should have at least one degraded event
      final degradedEvents = events
          .whereType<HealthChangeEvent>()
          .where((e) => e.health == DeviceHealth.degraded)
          .toList();
      expect(degradedEvents.isNotEmpty, true);
      expect(
        degradedEvents.first.reason,
        HealthChangeReason.heartbeatTimeout3x,
      );

      hb.stop();
      hb.dispose();
    });

    test('healthStream only emits on change', () async {
      final hb = SmartHeartbeatManager(
        idleThreshold: const Duration(milliseconds: 30),
        checkInterval: const Duration(milliseconds: 20),
        maxHeartbeatFailures: 5, // high threshold to avoid extra events
        onSendHeartbeat: () async => const HeartbeatResult(success: true),
      );

      final events = <HealthChangeEvent>[];
      hb.healthStream.listen(events.add);

      hb.start();
      hb.onMqttOnline();

      // Wait for multiple heartbeats
      await Future.delayed(const Duration(milliseconds: 200));

      // Should have only 1 healthy event (no duplicate emissions)
      final healthyCount = events
          .whereType<HealthChangeEvent>()
          .where((e) => e.health == DeviceHealth.healthy)
          .length;
      expect(healthyCount, 1);

      hb.stop();
      hb.dispose();
    });

    test('onKlippyStateChanged transitions to degraded', () {
      final hb = SmartHeartbeatManager(
        onSendHeartbeat: () async => const HeartbeatResult(success: true),
      );

      hb.onMqttOnline();
      // Simulate healthy state via MQTT online + no failure count
      // But we haven't had a heartbeat yet, so health may still be degraded...
      // Let's verify klippy disconnect works:
      hb.onKlippyStateChanged(connected: false);
      expect(hb.health, DeviceHealth.degraded);
      expect(hb.lastReason, HealthChangeReason.klipperDisconnected);

      hb.onKlippyStateChanged(connected: true);
      // After klippy reconnects, health should be re-evaluated
      // MQTT is online, no failures → should be healthy
      expect(hb.health, DeviceHealth.healthy);

      hb.dispose();
    });
  });

  group('SmartHeartbeatManager — reset', () {
    test('reset clears all state', () {
      final hb = SmartHeartbeatManager(
        onSendHeartbeat: () async => const HeartbeatResult(success: true),
      );

      hb.onMqttOnline();
      hb.start();
      hb.recordCommunication();

      hb.reset();

      expect(hb.health, DeviceHealth.unreachable);
      expect(hb.lastReason, HealthChangeReason.unknown);
      expect(hb.currentState.failCount, 0);
      expect(hb.currentState.lastOk, isNull);

      hb.dispose();
    });
  });
}
