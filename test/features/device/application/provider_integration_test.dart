import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_session_provider.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_list_provider.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_command_service_provider.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_session.dart';

/// Provider layer integration tests.
///
/// Verifies the Riverpod dependency graph compiles and basic provider
/// resolution works correctly.
void main() {
  test('ProviderContainer resolves deviceRegistryProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Verify registry can be resolved
    final registry = container.read(deviceRegistryProvider);
    expect(registry, isNotNull);
    expect(registry.devices, isEmpty);
  });

  test('ProviderContainer resolves deviceSessionProvider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final session = container.read(deviceSessionProvider);
    expect(session, isNotNull);
    expect(session.state, isA<DeviceSessionIdle>());
    expect(session.activeDevice, isNull);
  });

  test('ProviderContainer resolves activeDeviceProvider as null initially', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final activeDevice = container.read(activeDeviceProvider);
    expect(activeDevice, isNull);
  });

  test('ProviderContainer resolves deviceListProvider as empty initially', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final devices = container.read(deviceListProvider);
    expect(devices, isEmpty);
  });

  test('ProviderContainer resolves deviceCountProvider as 0', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final count = container.read(deviceCountProvider);
    expect(count, equals(0));
  });

  test('isDeviceActiveProvider resolves false initially', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final isActive = container.read(isDeviceActiveProvider);
    expect(isActive, isFalse);
  });

  test('deviceSession starts in idle state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Verify via the session provider directly (synchronous read).
    final session = container.read(deviceSessionProvider);
    expect(session.state, isA<DeviceSessionIdle>());
  });
}
