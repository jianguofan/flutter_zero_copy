import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_metadata_store_provider.dart';

/// Reactive list of all registered devices.
///
/// Rebuilds whenever a device is added, removed, or updated.
/// ✅ 重构后从 DeviceMetadataStore (StateNotifier) 读取
final deviceListProvider = Provider<List<DeviceInfo>>((ref) {
  // 监听 Store 的 state 变化
  ref.watch(deviceMetadataStoreProvider);

  // 从 Store 获取设备列表，转换为 DeviceInfo
  final notifier = ref.read(deviceMetadataStoreProvider.notifier);
  return notifier.allDevices.map((metadata) {
    return DeviceInfo(
      id: metadata.sn,
      name: metadata.displayName,
      sn: metadata.sn,
      ipAddress: metadata.ipAddress,
      accessCode: metadata.accessCode,
      model: metadata.model,
      firmwareVersion: metadata.firmwareVersion,
      isOnline: metadata.isOnline,
    );
  }).toList();
});

/// Number of registered devices.
final deviceCountProvider = Provider<int>((ref) {
  final devices = ref.watch(deviceListProvider);
  return devices.length;
});
