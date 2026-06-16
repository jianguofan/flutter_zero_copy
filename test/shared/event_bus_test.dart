import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zero_copy/shared/event_bus/event_bus.dart';

// ── Test events ──

class DeviceConnected {
  final String deviceId;
  const DeviceConnected(this.deviceId);
}

class DeviceDisconnected {
  final String deviceId;
  const DeviceDisconnected(this.deviceId);
}

class TemperatureUpdate {
  final double value;
  const TemperatureUpdate(this.value);
}

void main() {
  group('EventBus', () {
    late EventBus bus;

    setUp(() {
      bus = EventBus();
    });

    test('fire delivers event to listener', () {
      DeviceConnected? received;
      bus.on<DeviceConnected>((e) => received = e);
      bus.fire(const DeviceConnected('printer-1'));
      expect(received?.deviceId, equals('printer-1'));
    });

    test('fire does not deliver to different type listeners', () {
      DeviceConnected? received;
      bus.on<DeviceConnected>((e) => received = e);
      bus.fire(const DeviceDisconnected('printer-1'));
      expect(received, isNull);
    });

    test('multiple listeners for same type all receive event', () {
      final List<String> ids = [];
      bus.on<DeviceConnected>((e) => ids.add('A:${e.deviceId}'));
      bus.on<DeviceConnected>((e) => ids.add('B:${e.deviceId}'));
      bus.fire(const DeviceConnected('printer-1'));
      expect(ids, contains('A:printer-1'));
      expect(ids, contains('B:printer-1'));
      expect(ids.length, equals(2));
    });

    test('cancel removes listener', () {
      final List<String> ids = [];
      final sub = bus.on<DeviceConnected>((e) => ids.add(e.deviceId));
      bus.fire(const DeviceConnected('first'));
      sub.cancel();
      bus.fire(const DeviceConnected('second'));
      expect(ids, equals(['first']));
    });

    test('different event types are isolated', () {
      final List<String> log = [];
      bus.on<DeviceConnected>((e) => log.add('connected:${e.deviceId}'));
      bus.on<TemperatureUpdate>((e) => log.add('temp:${e.value}'));
      bus.fire(const DeviceConnected('p1'));
      bus.fire(const TemperatureUpdate(200.0));
      expect(log, equals(['connected:p1', 'temp:200.0']));
    });

    test('dispose clears all handlers', () {
      final List<String> log = [];
      bus.on<DeviceConnected>((e) => log.add(e.deviceId));
      bus.dispose();
      bus.fire(const DeviceConnected('after-dispose'));
      expect(log, isEmpty);
    });

    test('fire with no listeners does not throw', () {
      expect(() => bus.fire(const DeviceConnected('orphan')), returnsNormally);
    });
  });
}
