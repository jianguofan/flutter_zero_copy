import 'dart:async';
import 'package:lava_device_sdk/lava_device_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('RequestTrackerManager', () {
    late RequestTrackerManager mgr;

    setUp(() {
      mgr = RequestTrackerManager();
      mgr.start();
    });
    tearDown(() {
      // Cancel pending futures silently to avoid unhandled async errors
      mgr.stop();
    });

    test('track returns future that completes with response', () async {
      final future = mgr.track(id: 'req-1', timeout: const Duration(seconds: 10));
      mgr.complete('req-1', {'result': 'ok'});

      final result = await future;
      expect(result['result'], 'ok');
    });

    test('track returns future that times out', () async {
      final future = mgr.track(id: 'req-2', timeout: const Duration(milliseconds: 50));

      // Wait for the cleanup timer to fire
      await expectLater(future, throwsA(isA<TimeoutException>()));
    });

    test('complete ignores non-existent requests silently', () {
      mgr.complete('nonexistent', {'nope': true});
      // Should not throw
    });

    test('complete ignores already-completed requests', () async {
      final future = mgr.track(id: 'req-3', timeout: const Duration(seconds: 10));
      mgr.complete('req-3', {'first': true});

      // Second complete should be ignored
      mgr.complete('req-3', {'second': true});

      final result = await future;
      expect(result['first'], true);
    });

    test('pendingCount reflects active requests', () async {
      // Capture futures so they don't cause unhandled errors on stop()
      final f1 = mgr.track(id: 'a', timeout: const Duration(seconds: 10));
      final f2 = mgr.track(id: 'b', timeout: const Duration(seconds: 10));
      expect(mgr.pendingCount, 2);

      mgr.complete('a', {});
      await f1; // consume
      expect(mgr.pendingCount, 1);

      mgr.complete('b', {});
      await f2; // consume
      expect(mgr.pendingCount, 0);
    });

    test('stop completes all pending with error', () async {
      final future = mgr.track(id: 'req-4', timeout: const Duration(seconds: 30));

      // Stop before tearDown's stop (which is a no-op after explicit stop)
      mgr.stop();

      await expectLater(future, throwsA(isA<TimeoutException>()));
      expect(mgr.pendingCount, 0);
    });
  });
}
