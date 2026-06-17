import 'package:flutter/foundation.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_metadata.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_registry.dart';

/// DeviceMetadataStore — 设备元数据中心 ⭐
///
/// **核心价值**: 所有设备数据的唯一读写入口
///
/// **重构**: 不再继承 ChangeNotifier，改用纯数据类 + Riverpod StateNotifier
///
/// - 所有数据源（MQTT、云端、本地）只往 Store 写
/// - 所有消费者（UI、Provider、日志）只从 Store 读
/// - 中间件（校验、合并策略、staleness、快照、变更日志）全部在 Store 内集中处理
///
/// **写入入口**:
/// - `onMqttStatusUpdate()` — MQTT 状态推送
/// - `onCloudDeviceList()` — 云端 device/list 轮询
/// - `onDeviceRegistered()` — 用户注册/更新设备
/// - `onConnectionStateChanged()` — 连接状态变化
///
/// **读取出口**:
/// - `getDevice(sn)` — 获取单个设备
/// - `allDevices` — 获取所有设备
/// - `deviceCount` — 设备数量
///
/// **中间件**:
/// - 字段合并策略 (云端字段 + 本地字段 + MQTT 遥测)
/// - staleness 标记 (连接断开时标记数据过期)
/// - 快照触发 (关键事件自动采集快照)
/// - 数据校验 (写入时验证数据格式)
class DeviceMetadataStore {
  final Map<String, DeviceMetadata> _devices = {};
  final IDeviceRegistry _registry;

  DeviceMetadataStore({
    required IDeviceRegistry registry,
  }) : _registry = registry;

  // ══════════════════════════════════════════════════════════════
  // 写入入口 (返回新的 Map，触发 Riverpod 状态更新)
  // ══════════════════════════════════════════════════════════════

  /// MQTT 状态推送 → 写入选定设备的遥测字段
  ///
  /// **调用者**: DeviceImpl._onMqttMessage()
  /// **频率**: 高频 (每秒多次)
  /// **中间件**: 字段校验 → 写入 → 标记新鲜 → 触发快照
  /// **返回**: 新的设备 Map（触发 Riverpod 更新）
  Map<String, DeviceMetadata> onMqttStatusUpdate(String sn, Map<String, dynamic> status) {
    final device = _devices[sn];
    if (device == null) {
      debugPrint('⚠️  Store: MQTT update for unknown device $sn');
      return _devices;
    }

    // 中间件: 数据校验
    if (!_validateMqttStatus(status)) {
      debugPrint('⚠️  Store: Invalid MQTT status for $sn');
      return _devices;
    }

    // 写入遥测字段
    device.updateTelemetry(status);

    // 中间件: 快照触发 (可选，根据状态变化)
    _maybeCaptureSnapshot(sn, 'mqtt_update', status);

    // 返回新的 Map 引用（触发 Riverpod 更新）
    return Map.from(_devices);
  }

  /// 云端 device/list 全量返回 → 合并云端字段
  ///
  /// **调用者**: cloudDeviceListProvider (Timer 60s 轮询)
  /// **频率**: 低频 (每60s)
  /// **规则**: 已存在的设备只更新云端字段，不覆盖本地字段；不删除不在 list 中的本地设备
  Map<String, DeviceMetadata> onCloudDeviceList(List<Map<String, dynamic>> list) {
    for (final dto in list) {
      final sn = dto['sn'] as String?;
      if (sn == null) continue;

      final device = _devices[sn];
      if (device != null) {
        // 已存在 → 只更新云端字段
        device.updateCloud(dto);
      } else {
        // 新设备 → 从云端创建
        _devices[sn] = DeviceMetadata.fromCloud(dto);
      }
    }

    // 关键：不删除不在 list 中的设备（纯本地 LAN 设备保留）
    return Map.from(_devices);
  }

  /// 用户注册/更新设备
  ///
  /// **调用者**: DeviceRegistry.register()
  /// **频率**: 低频 (用户手动操作)
  /// **规则**: 已存在的设备只更新本地字段，不覆盖云端字段
  Map<String, DeviceMetadata> onDeviceRegistered(DeviceInfo info) {
    final device = _devices[info.sn];
    if (device != null) {
      // 已存在 → 只更新本地字段
      device.updateLocal(info);
    } else {
      // 新设备 → 从本地创建
      _devices[info.sn] = DeviceMetadata.fromLocal(info);
    }

    return Map.from(_devices);
  }

  /// 连接状态变化 → 标记 staleness + 触发快照
  ///
  /// **调用者**: DeviceImpl._onConnectionStateChanged()
  /// **中间件**: staleness 标记 + 快照触发
  Map<String, DeviceMetadata> onConnectionStateChanged(
    String sn,
    DeviceConnectionState state,
  ) {
    final device = _devices[sn];
    if (device == null) return _devices;

    // 更新连接状态
    device.connectionState = state;

    // 中间件: staleness 标记
    switch (state) {
      case DeviceConnectionState.disconnected:
      case DeviceConnectionState.reconnecting:
      case DeviceConnectionState.failed:
        // 实时遥测数据标记为过期
        device.markTelemetryStale();
        _captureSnapshot(sn, 'connection_lost');
        break;
      case DeviceConnectionState.connected:
        // 保持 stale，等 MQTT 推送新数据
        _captureSnapshot(sn, 'connected');
        break;
      case DeviceConnectionState.handshaking:
      case DeviceConnectionState.degraded:
        // 连接中，保持当前状态
        break;
      case DeviceConnectionState.connecting:
      case DeviceConnectionState.idle:
        // 不处理
        break;
    }

    return Map.from(_devices);
  }

  /// 设备注销
  ///
  /// **调用者**: DeviceRegistry.unregister()
  Map<String, DeviceMetadata> onDeviceUnregistered(String sn) {
    if (_devices.remove(sn) != null) {
      debugPrint('✅ Store: Device $sn removed');
      return Map.from(_devices);
    }
    return _devices;
  }

  // ══════════════════════════════════════════════════════════════
  // 快照管理
  // ══════════════════════════════════════════════════════════════

  /// 采集设备快照 (用于调试和故障排查)
  void _captureSnapshot(
    String sn,
    String reason, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final device = _devices[sn];
    if (device == null) return;

    device.addSnapshot(DeviceSnapshot(
      timestamp: DateTime.now(),
      reason: reason,
      deviceId: sn,
      context: context,
      nozzleTemp: device.nozzleTemp?.value,
      bedTemp: device.bedTemp?.value,
      printState: device.printState?.value,
      progress: device.progress?.value,
      filamentUsed: device.filamentUsed,
      connectionState: device.connectionState,
      isConnected: device.connectionState == DeviceConnectionState.connected,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    ));
  }

  /// 条件性触发快照 (根据状态变化)
  void _maybeCaptureSnapshot(
    String sn,
    String reason,
    Map<String, dynamic> status,
  ) {
    // 打印状态变化时触发快照
    if (status.containsKey('print_state')) {
      final printState = status['print_state'] as String?;
      if (printState == 'printing' || printState == 'paused' || printState == 'completed') {
        _captureSnapshot(sn, reason, context: 'Print state: $printState');
      }
    }
  }

  /// 外部触发快照 (命令失败等)
  ///
  /// **调用者**: DeviceImpl.sendCommand() catch 块
  /// **返回**: 新的设备 Map（触发更新）
  Map<String, DeviceMetadata> captureSnapshot(
    String sn,
    String reason, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _captureSnapshot(
      sn,
      reason,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
    return Map.from(_devices);
  }

  // ══════════════════════════════════════════════════════════════
  // 读取出口
  // ══════════════════════════════════════════════════════════════

  /// 获取单个设备元数据
  DeviceMetadata? getDevice(String sn) => _devices[sn];

  /// 获取所有设备元数据
  List<DeviceMetadata> get allDevices => _devices.values.toList();

  /// 设备数量
  int get deviceCount => _devices.length;

  /// 检查设备是否存在
  bool hasDevice(String sn) => _devices.containsKey(sn);

  // ══════════════════════════════════════════════════════════════
  // 初始化
  // ══════════════════════════════════════════════════════════════

  /// 从 Registry 加载已注册的设备
  ///
  /// **调用时机**: App 启动时，在 deviceMetadataStoreProvider 初始化后
  Map<String, DeviceMetadata> loadFromRegistry() {
    _devices.clear();
    for (final info in _registry.devices) {
      _devices[info.sn] = DeviceMetadata.fromLocal(info);
    }
    debugPrint('✅ Store: Loaded ${_devices.length} devices from registry');
    return Map.from(_devices);
  }

  // ══════════════════════════════════════════════════════════════
  // 中间件: 数据校验
  // ══════════════════════════════════════════════════════════════

  bool _validateMqttStatus(Map<String, dynamic> status) {
    // 基本校验: 至少包含一个已知字段
    final knownFields = [
      'nozzle_temp',
      'bed_temp',
      'chamber_temp',
      'print_state',
      'progress',
      'filament_used',
      'total_duration',
    ];

    return status.keys.any((key) => knownFields.contains(key));
  }
}
