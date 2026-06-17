import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/features/device/data/stores/device_metadata_store.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_metadata.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_session_provider.dart';

/// DeviceMetadataStoreNotifier - 管理设备元数据状态
///
/// **使用 StateNotifier 替代 ChangeNotifier**，符合 Riverpod 最佳实践
///
/// State: Map<String, DeviceMetadata> - 所有设备的元数据
class DeviceMetadataStoreNotifier extends StateNotifier<Map<String, DeviceMetadata>> {
  final DeviceMetadataStore _store;

  DeviceMetadataStoreNotifier(this._store) : super({}) {
    // 初始化：从 Registry 加载设备
    state = _store.loadFromRegistry();
  }

  // 暴露 Store 实例（用于 DeviceImpl 直接调用）
  DeviceMetadataStore get store => _store;

  // ══════════════════════════════════════════════════════════════
  // 写入入口 (更新 state，触发 Riverpod 自动通知)
  // ══════════════════════════════════════════════════════════════

  void onMqttStatusUpdate(String sn, Map<String, dynamic> status) {
    state = _store.onMqttStatusUpdate(sn, status);
  }

  void onCloudDeviceList(List<Map<String, dynamic>> list) {
    state = _store.onCloudDeviceList(list);
  }

  void onDeviceRegistered(DeviceInfo info) {
    state = _store.onDeviceRegistered(info);
  }

  void onConnectionStateChanged(String sn, DeviceConnectionState state) {
    this.state = _store.onConnectionStateChanged(sn, state);
  }

  void onDeviceUnregistered(String sn) {
    state = _store.onDeviceUnregistered(sn);
  }

  void captureSnapshot(
    String sn,
    String reason, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    state = _store.captureSnapshot(
      sn,
      reason,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 读取接口 (委托给 Store)
  // ══════════════════════════════════════════════════════════════

  DeviceMetadata? getDevice(String sn) => _store.getDevice(sn);
  List<DeviceMetadata> get allDevices => _store.allDevices;
  int get deviceCount => _store.deviceCount;
  bool hasDevice(String sn) => _store.hasDevice(sn);
}

/// DeviceMetadataStore StateNotifierProvider
///
/// **用法**:
/// ```dart
/// // 读取设备列表 (自动监听变化)
/// final devices = ref.watch(deviceMetadataStoreProvider.notifier).allDevices;
///
/// // 写入数据
/// ref.read(deviceMetadataStoreProvider.notifier).onMqttStatusUpdate(sn, status);
///
/// // 监听 state 变化
/// ref.watch(deviceMetadataStoreProvider); // Map<String, DeviceMetadata>
/// ```
final deviceMetadataStoreProvider =
    StateNotifierProvider<DeviceMetadataStoreNotifier, Map<String, DeviceMetadata>>((ref) {
  final registry = ref.watch(deviceRegistryProvider);
  final store = DeviceMetadataStore(registry: registry);
  return DeviceMetadataStoreNotifier(store);
});

/// 便捷访问：获取所有设备列表
///
/// **用法**: `final devices = ref.watch(allDeviceMetadataProvider);`
final allDeviceMetadataProvider = Provider<List<DeviceMetadata>>((ref) {
  final notifier = ref.watch(deviceMetadataStoreProvider.notifier);
  ref.watch(deviceMetadataStoreProvider); // 监听 state 变化
  return notifier.allDevices;
});

/// 便捷访问：获取设备数量
final deviceMetadataCountProvider = Provider<int>((ref) {
  final notifier = ref.watch(deviceMetadataStoreProvider.notifier);
  ref.watch(deviceMetadataStoreProvider); // 监听 state 变化
  return notifier.deviceCount;
});

/// 便捷访问：获取单个设备
///
/// **用法**: `final device = ref.watch(deviceMetadataProvider('sn123'));`
final deviceMetadataProvider = Provider.family<DeviceMetadata?, String>((ref, sn) {
  final notifier = ref.watch(deviceMetadataStoreProvider.notifier);
  ref.watch(deviceMetadataStoreProvider); // 监听 state 变化
  return notifier.getDevice(sn);
});
