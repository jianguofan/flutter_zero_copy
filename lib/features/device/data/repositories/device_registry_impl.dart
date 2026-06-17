import 'dart:convert';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_registry.dart';
import 'package:flutter_zero_copy/shared/storage/storage.dart';

/// [IDeviceRegistry] implementation backed by Hive storage.
///
/// Persists device list to disk for survival across app restarts.
class DeviceRegistryImpl implements IDeviceRegistry {
  final HiveStorage _storage;
  static const _keyDevices = 'registry.devices';
  static const _keyActiveDevice = 'registry.activeDeviceId';

  List<DeviceInfo> _devices = [];

  DeviceRegistryImpl({required HiveStorage storage}) : _storage = storage;

  @override
  List<DeviceInfo> get devices => List.unmodifiable(_devices);

  @override
  DeviceInfo? lookup(String deviceId) {
    try {
      return _devices.firstWhere((d) => d.id == deviceId);
    } catch (_) {
      return null;
    }
  }

  @override
  DeviceInfo? lookupBySn(String sn) {
    try {
      return _devices.firstWhere((d) => d.sn == sn);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> register(DeviceInfo device) async {
    final index = _devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      _devices[index] = device;
    } else {
      _devices.add(device);
    }
    await _persist();
  }

  @override
  Future<void> unregister(String deviceId) async {
    _devices.removeWhere((d) => d.id == deviceId);
    await _persist();
  }

  @override
  Future<void> setActiveDevice(String deviceId) async {
    await _storage.setString(_keyActiveDevice, deviceId);
  }

  @override
  String? getActiveDeviceId() => _storage.getString(_keyActiveDevice);

  @override
  Future<void> clearActiveDevice() async {
    await _storage.remove(_keyActiveDevice);
  }

  @override
  Future<void> load() async {
    await _storage.init();
    final raw = _storage.getString(_keyDevices);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _devices = list
          .map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  @override
  int get count => _devices.length;

  // ── Internal ──

  Future<void> _persist() async {
    await _storage.init(); // ensure Hive box is open
    final json = _devices.map((d) => d.toJson()).toList();
    await _storage.setString(_keyDevices, jsonEncode(json));
  }
}
