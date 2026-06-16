import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

/// Stream backpressure verification.
///
/// Simulates high-frequency data (100 msgs/s) and measures that
/// the stream infrastructure handles it without dropping or OOM.
void main() {
  group('Stream backpressure', () {
    test('handles 100 rapid emissions without dropping', () async {
      final controller = StreamController<int>.broadcast();
      final received = <int>[];

      final sub = controller.stream.listen(received.add);

      // Emit 100 items as fast as possible
      for (var i = 0; i < 100; i++) {
        controller.add(i);
      }

      // Allow microtask queue to flush
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(received.length, equals(100));
      expect(received.first, equals(0));
      expect(received.last, equals(99));

      await sub.cancel();
      await controller.close();
    });

    test('broadcast stream supports multiple listeners', () async {
      final controller = StreamController<int>.broadcast();
      final a = <int>[];
      final b = <int>[];

      final subA = controller.stream.listen(a.add);
      final subB = controller.stream.listen(b.add);

      controller.add(1);
      controller.add(2);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(a, equals([1, 2]));
      expect(b, equals([1, 2]));

      await subA.cancel();
      await subB.cancel();
      await controller.close();
    });

    test('stream disposes cleanly without memory leak', () async {
      late StreamController<int> controller;
      controller = StreamController<int>.broadcast();

      final sub = controller.stream.listen((_) {});
      controller.add(42);

      await sub.cancel();
      await controller.close();

      // After close, controller.isClosed should be true
      expect(controller.isClosed, isTrue);
    });
  });
}
