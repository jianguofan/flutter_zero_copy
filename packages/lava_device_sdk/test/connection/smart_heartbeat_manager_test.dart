import 'dart:async';
import 'package:lava_device_sdk/lava_device_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('SmartHeartbeatManager', () {
    test('sends heartbeat when idle exceeds threshold', () async {
      int heartbeatCount = 0;
      final hb = SmartHeartbeatManager(
        idleThreshold: const Duration(milliseconds: 50),
        checkInterval: const Duration(milliseconds: 20),
        onSendHeartbeat: () async {
          heartbeatCount++;
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
}
