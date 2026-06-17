import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';

/// 设备元数据 - 合并本地、云端、MQTT 遥测数据
class DeviceMetadata {
  // ══════════════════════════════════════════════════════════════
  // 本地字段 (来自 Registry + 用户操作)
  // ══════════════════════════════════════════════════════════════
  final String sn;
  String? name;
  String? ipAddress;
  String? accessCode;
  String? pinCode;
  String? model;
  String? firmwareVersion;

  // ══════════════════════════════════════════════════════════════
  // 云端字段 (来自 device/list 轮询)
  // ══════════════════════════════════════════════════════════════
  int? cloudDeviceId;
  String? cloudName;
  bool? cloudOnline;
  int? printHours;

  // ══════════════════════════════════════════════════════════════
  // 遥测字段 (来自 MQTT 实时推送, Staleable)
  // ══════════════════════════════════════════════════════════════
  Staleable<double>? nozzleTemp;
  Staleable<double>? bedTemp;
  Staleable<double>? chamberTemp;
  Staleable<String>? printState;
  Staleable<int>? progress;

  // ══════════════════════════════════════════════════════════════
  // 累积指标 (不断开不清)
  // ══════════════════════════════════════════════════════════════
  double? filamentUsed;
  int? totalDuration;

  // ══════════════════════════════════════════════════════════════
  // 连接状态
  // ══════════════════════════════════════════════════════════════
  DeviceConnectionState connectionState = DeviceConnectionState.idle;

  // ══════════════════════════════════════════════════════════════
  // 快照 (环形缓冲, 最近 20 条)
  // ══════════════════════════════════════════════════════════════
  static const _maxSnapshots = 20;
  final List<DeviceSnapshot> _snapshots = [];

  DeviceMetadata({
    required this.sn,
    this.name,
    this.ipAddress,
    this.accessCode,
    this.pinCode,
    this.model,
    this.firmwareVersion,
    this.cloudDeviceId,
    this.cloudName,
    this.cloudOnline,
    this.printHours,
  });

  // ══════════════════════════════════════════════════════════════
  // 工厂构造函数
  // ══════════════════════════════════════════════════════════════

  /// 从本地 Registry 创建
  factory DeviceMetadata.fromLocal(DeviceInfo info) {
    return DeviceMetadata(
      sn: info.sn,
      name: info.name,
      ipAddress: info.ipAddress,
      accessCode: info.accessCode,
      pinCode: info.pinCode,
      model: info.model,
      firmwareVersion: info.firmwareVersion,
    );
  }

  /// 从云端 device/list 创建
  factory DeviceMetadata.fromCloud(Map<String, dynamic> cloudDto) {
    return DeviceMetadata(
      sn: cloudDto['sn'] as String,
      cloudDeviceId: cloudDto['id'] as int?,
      cloudName: cloudDto['name'] as String?,
      cloudOnline: cloudDto['online'] as bool?,
      printHours: cloudDto['print_hours'] as int?,
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 更新方法
  // ══════════════════════════════════════════════════════════════

  /// 更新本地字段 (来自 Registry)
  void updateLocal(DeviceInfo info) {
    name = info.name;
    ipAddress = info.ipAddress;
    accessCode = info.accessCode;
    pinCode = info.pinCode;
    model = info.model;
    firmwareVersion = info.firmwareVersion;
  }

  /// 更新云端字段 (来自 device/list)
  void updateCloud(Map<String, dynamic> cloudDto) {
    cloudDeviceId = cloudDto['id'] as int?;
    cloudName = cloudDto['name'] as String?;
    cloudOnline = cloudDto['online'] as bool?;
    printHours = cloudDto['print_hours'] as int?;
  }

  /// 更新遥测字段 (来自 MQTT)
  void updateTelemetry(Map<String, dynamic> status) {
    final now = DateTime.now();

    // 温度字段
    if (status.containsKey('nozzle_temp')) {
      nozzleTemp = Staleable(
        status['nozzle_temp'] as double,
        updatedAt: now,
        isStale: false,
      );
    }
    if (status.containsKey('bed_temp')) {
      bedTemp = Staleable(
        status['bed_temp'] as double,
        updatedAt: now,
        isStale: false,
      );
    }
    if (status.containsKey('chamber_temp')) {
      chamberTemp = Staleable(
        status['chamber_temp'] as double,
        updatedAt: now,
        isStale: false,
      );
    }

    // 打印状态
    if (status.containsKey('print_state')) {
      printState = Staleable(
        status['print_state'] as String,
        updatedAt: now,
        isStale: false,
      );
    }
    if (status.containsKey('progress')) {
      progress = Staleable(
        status['progress'] as int,
        updatedAt: now,
        isStale: false,
      );
    }

    // 累积指标
    if (status.containsKey('filament_used')) {
      filamentUsed = status['filament_used'] as double?;
    }
    if (status.containsKey('total_duration')) {
      totalDuration = status['total_duration'] as int?;
    }
  }

  /// 标记遥测字段为过期 (连接断开时)
  void markTelemetryStale() {
    nozzleTemp = nozzleTemp?.copyWith(isStale: true);
    bedTemp = bedTemp?.copyWith(isStale: true);
    chamberTemp = chamberTemp?.copyWith(isStale: true);
    printState = printState?.copyWith(isStale: true);
    progress = progress?.copyWith(isStale: true);
  }

  // ══════════════════════════════════════════════════════════════
  // 快照管理
  // ══════════════════════════════════════════════════════════════

  List<DeviceSnapshot> get snapshots => List.unmodifiable(_snapshots);
  DeviceSnapshot? get lastSnapshot =>
      _snapshots.isNotEmpty ? _snapshots.last : null;

  void addSnapshot(DeviceSnapshot snapshot) {
    _snapshots.add(snapshot);
    if (_snapshots.length > _maxSnapshots) {
      _snapshots.removeAt(0);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 展示字段 (合并后)
  // ══════════════════════════════════════════════════════════════

  /// 优先显示本地名称，其次云端名称，最后 SN
  String get displayName => name ?? cloudName ?? sn;

  /// 连接在线 或 云端在线
  bool get isOnline =>
      connectionState == DeviceConnectionState.connected ||
      cloudOnline == true;

  // ══════════════════════════════════════════════════════════════
  // 字段访问 (支持路径查询)
  // ══════════════════════════════════════════════════════════════

  T? getField<T>(String path) {
    switch (path) {
      case 'temperature.nozzle':
        return nozzleTemp?.value as T?;
      case 'temperature.bed':
        return bedTemp?.value as T?;
      case 'temperature.chamber':
        return chamberTemp?.value as T?;
      case 'print.state':
        return printState?.value as T?;
      case 'print.progress':
        return progress?.value as T?;
      case 'filament.used':
        return filamentUsed as T?;
      case 'print.duration':
        return totalDuration as T?;
      case 'name':
        return displayName as T?;
      case 'online':
        return isOnline as T?;
      default:
        return null;
    }
  }
}

// ══════════════════════════════════════════════════════════════════
// Staleable - 带新鲜度标记的值
// ══════════════════════════════════════════════════════════════════

/// 可过期的值 (用于实时遥测数据)
class Staleable<T> {
  final T value;
  final DateTime updatedAt;
  final bool isStale;

  const Staleable(
    this.value, {
    required this.updatedAt,
    this.isStale = false,
  });

  Staleable<T> copyWith({
    T? value,
    DateTime? updatedAt,
    bool? isStale,
  }) {
    return Staleable<T>(
      value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      isStale: isStale ?? this.isStale,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// DeviceSnapshot - 设备快照
// ══════════════════════════════════════════════════════════════════

/// 设备快照 (用于调试和故障排查)
class DeviceSnapshot {
  final DateTime timestamp;
  final String reason; // connected | disconnect | command_failed | connection_lost
  final String deviceId;
  final String? context; // 人类可读上下文

  final double? nozzleTemp;
  final double? bedTemp;
  final String? printState;
  final int? progress;
  final double? filamentUsed;

  final DeviceConnectionState connectionState;
  final bool isConnected;

  final String? error;
  final String? stackTrace;

  DeviceSnapshot({
    required this.timestamp,
    required this.reason,
    required this.deviceId,
    this.context,
    this.nozzleTemp,
    this.bedTemp,
    this.printState,
    this.progress,
    this.filamentUsed,
    required this.connectionState,
    required this.isConnected,
    this.error,
    this.stackTrace,
  });
}
