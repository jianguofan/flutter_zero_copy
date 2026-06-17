import 'dart:async';

import 'package:flutter_zero_copy/features/device/application/providers/device_metadata_store_provider.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_command.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_message.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_connection.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';
import 'package:rxdart/rxdart.dart';

/// Aggregate root implementing [IDeviceFacade].
///
/// **重构后职责**:
/// - MQTT 消息 → 通过 StateNotifier 写入 Store
/// - 不再自己缓存字段数据
/// - fieldStream / getField → 从 Notifier 读取
/// - sendCommand → 发送命令，失败时触发快照
///
/// **依赖注入**: DeviceMetadataStoreNotifier (Riverpod StateNotifier)
class DeviceImpl implements IDeviceFacade {
  @override
  final DeviceInfo info;

  final IConnection _connection;
  final DeviceMetadataStoreNotifier _notifier; // ← 注入 StateNotifier

  // ── State ──
  final BehaviorSubject<DeviceConnectionState> _connectionStateSubject;
  DeviceConnectionState _connectionState = DeviceConnectionState.idle;
  StreamSubscription? _statusSub;
  StreamSubscription? _messageSub;

  DeviceImpl({
    required this.info,
    required IConnection connection,
    required DeviceMetadataStoreNotifier notifier, // ← 构造函数注入
  })  : _connection = connection,
        _notifier = notifier,
        _connectionStateSubject = BehaviorSubject<DeviceConnectionState>.seeded(
            DeviceConnectionState.idle) {
    _listenToConnection();
  }

  // ══════════════════════════════════════════════════════════════
  // IDeviceFacade
  // ══════════════════════════════════════════════════════════════

  @override
  DeviceConnectionState get connectionState => _connectionState;

  @override
  Stream<DeviceConnectionState> get connectionStateStream =>
      _connectionStateSubject.stream;

  @override
  Stream<DeviceMessage> get messageStream => _connection.messageStream;

  @override
  Stream<T> fieldStream<T>(String fieldPath) {
    // ✅ 从 Notifier 读取字段流
    // 定期从 Notifier 读取最新值
    return Stream.periodic(const Duration(milliseconds: 500), (_) {
      return _notifier.getDevice(info.sn)?.getField<T>(fieldPath);
    }).whereType<T>().distinct();
  }

  @override
  T? getField<T>(String fieldPath) {
    // ✅ 从 Notifier 读取字段快照
    return _notifier.getDevice(info.sn)?.getField<T>(fieldPath);
  }

  @override
  Future<CommandResult> sendCommand(DeviceCommand command) async {
    try {
      await _connection.send(DeviceMessage(
        topic: 'command',
        payload: {
          'method': command.method,
          if (command.params != null) 'params': command.params,
        },
        timestamp: DateTime.now(),
      ));

      return CommandResult(
        commandId: command.id,
        success: true,
        completedAt: DateTime.now(),
      );
    } catch (e, st) {
      // ✅ 命令失败 → 触发快照（通过 Notifier）
      _notifier.captureSnapshot(
        info.sn,
        'command_failed',
        context: '发送命令: ${command.method}',
        error: e,
        stackTrace: st,
      );

      return CommandResult(
        commandId: command.id,
        success: false,
        message: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════

  /// Establish transport connection.
  ///
  /// Reconnection on disconnect is handled automatically by the SDK's
  /// [MqttTransport] exponential-backoff mechanism — no separate watchdog
  /// timer is needed at this layer.
  Future<void> connect() async {
    _setState(DeviceConnectionState.connecting);
    try {
      await _connection.connect();
      _setState(DeviceConnectionState.connected);
    } catch (e) {
      _setState(DeviceConnectionState.failed);
      rethrow;
    }
  }

  /// Tear down connection.
  Future<void> disconnect() async {
    await _connection.disconnect();
    _setState(DeviceConnectionState.disconnected);
  }

  /// Release all resources.
  Future<void> dispose() async {
    await _statusSub?.cancel();
    await _messageSub?.cancel();
    await _connectionStateSubject.close();
  }

  // ══════════════════════════════════════════════════════════════
  // Connection listener
  // ══════════════════════════════════════════════════════════════

  void _listenToConnection() {
    _statusSub = _connection.statusStream.listen((status) {
      _setState(_mapConnectionStatus(status));
    });

    _messageSub = _connection.messageStream.listen((msg) {
      _onMqttMessage(msg);
    });
  }

  /// ✅ MQTT 消息 → 通过 Notifier 写入 Store
  void _onMqttMessage(DeviceMessage msg) {
    // 通过 Notifier 写入，Notifier 会更新 state，触发 Riverpod 通知
    _notifier.onMqttStatusUpdate(info.sn, msg.payload);
  }

  void _setState(DeviceConnectionState newState) {
    if (_connectionState == newState) return;
    _connectionState = newState;
    _connectionStateSubject.add(newState);

    // ✅ 连接状态变化 → 通过 Notifier 通知（触发 staleness + 快照）
    _notifier.onConnectionStateChanged(info.sn, newState);
  }

  DeviceConnectionState _mapConnectionStatus(ConnectionStatus status) {
    return switch (status) {
      ConnectionStatus.idle => DeviceConnectionState.idle,
      ConnectionStatus.connecting => DeviceConnectionState.connecting,
      ConnectionStatus.connected => DeviceConnectionState.connected,
      ConnectionStatus.disconnected => DeviceConnectionState.disconnected,
      ConnectionStatus.error => DeviceConnectionState.failed,
    };
  }
}
