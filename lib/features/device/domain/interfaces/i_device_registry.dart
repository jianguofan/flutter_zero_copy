import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';

/// Persistent device registry — CRUD for known devices.
///
/// The "active device" concept lives in [IDeviceSession], not here.
/// This separation prevents the dual-activeDevice problem identified
/// in the architecture review.
abstract class IDeviceRegistry {
  /// All registered devices.
  List<DeviceInfo> get devices;

  /// Look up a device by its ID.
  DeviceInfo? lookup(String deviceId);

  /// Look up a device by serial number.
  DeviceInfo? lookupBySn(String sn);

  /// Add or update a device in the registry.
  Future<void> register(DeviceInfo device);

  /// Remove a device from the registry.
  Future<void> unregister(String deviceId);

  /// Persist the ID of the last active device (for foreground restore).
  Future<void> setActiveDevice(String deviceId);

  /// Read the ID of the last active device.
  String? getActiveDeviceId();

  /// Clear the persisted active device marker.
  Future<void> clearActiveDevice();

  /// Reload the registry from persistent storage.
  Future<void> load();

  /// Number of registered devices.
  int get count;
}
