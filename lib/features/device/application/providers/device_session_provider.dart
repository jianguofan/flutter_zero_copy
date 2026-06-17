import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/features/device/data/repositories/device_registry_impl.dart';
import 'package:flutter_zero_copy/features/device/data/repositories/device_session_impl.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_metadata_store_provider.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_session.dart';
import 'package:flutter_zero_copy/shared/di/providers.dart';
import 'package:flutter_zero_copy/shared/storage/storage.dart';

/// The singleton [IDeviceSession] instance.
///
/// Manages the lifecycle of the "currently active device".
/// Depends on [deviceRegistryProvider] and [deviceMetadataStoreProvider].
final deviceSessionProvider = Provider<DeviceSessionImpl>((ref) {
  final registry = ref.watch(deviceRegistryProvider);
  final notifier = ref.watch(deviceMetadataStoreProvider.notifier);

  return DeviceSessionImpl(
    registry: registry,
    notifier: notifier, // ← 传递 Notifier
  );
});

/// Stream of [DeviceSessionState] for UI consumption.
///
/// Rebuilds whenever the session state changes (idle → activating → active → error).
final deviceSessionStateProvider = StreamProvider<DeviceSessionState>((ref) {
  final session = ref.watch(deviceSessionProvider);
  return session.stateStream;
});

/// Convenience: the currently active device facade, or null.
final activeDeviceProvider = Provider((ref) {
  final session = ref.watch(deviceSessionProvider);
  return session.activeDevice;
});

/// The [IDeviceRegistry] instance, backed by Hive.
///
/// Call `registry.load()` before first use (done in main.dart via startup logic).
final deviceRegistryProvider = Provider<DeviceRegistryImpl>((ref) {
  final storage = ref.watch(storageProvider) as HiveStorage;
  return DeviceRegistryImpl(storage: storage);
});
