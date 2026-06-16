import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_session_provider.dart';

/// Reactive list of all registered devices.
///
/// Rebuilds whenever a device is added, removed, or updated.
final deviceListProvider = Provider<List<DeviceInfo>>((ref) {
  final registry = ref.watch(deviceRegistryProvider);
  // Watch the session state to trigger rebuilds on register/unregister changes
  ref.watch(deviceSessionStateProvider);
  return registry.devices;
});

/// Number of registered devices.
final deviceCountProvider = Provider<int>((ref) {
  final devices = ref.watch(deviceListProvider);
  return devices.length;
});
