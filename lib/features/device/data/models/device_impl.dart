import 'dart:async';

import 'package:flutter_zero_copy/features/device/domain/entities/device_command.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_message.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_connection.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';
import 'package:rxdart/rxdart.dart';

/// Aggregate root implementing [IDeviceFacade].
///
/// Owns an [IConnection], manages heartbeat, message routing, and
/// field-level subscriptions with configurable backpressure.
class DeviceImpl implements IDeviceFacade {
  @override
  final DeviceInfo info;

  final IConnection _connection;
  Timer? _heartbeatTimer;

  // ── Field subscriptions ──
  final Map<String, BehaviorSubject<dynamic>> _fieldSubscriptions = {};

  // ── State ──
  final BehaviorSubject<DeviceConnectionState> _connectionStateSubject;
  DeviceConnectionState _connectionState = DeviceConnectionState.idle;
  StreamSubscription? _statusSub;
  StreamSubscription? _messageSub;

  DeviceImpl({
    required this.info,
    required IConnection connection,
  })  : _connection = connection,
        _connectionStateSubject =
            BehaviorSubject<DeviceConnectionState>.seeded(
                DeviceConnectionState.idle) {
    _listenToConnection();
  }

  // ── IDeviceFacade ──

  @override
  DeviceConnectionState get connectionState => _connectionState;

  @override
  Stream<DeviceConnectionState> get connectionStateStream =>
      _connectionStateSubject.stream;

  @override
  Stream<DeviceMessage> get messageStream => _connection.messageStream;

  @override
  Stream<T> fieldStream<T>(String fieldPath) {
    final sub = _fieldSubscriptions.putIfAbsent(
      fieldPath,
      () => BehaviorSubject<dynamic>(),
    );
    return sub.stream.cast<T>();
  }

  @override
  T? getField<T>(String fieldPath) {
    final sub = _fieldSubscriptions[fieldPath];
    if (sub == null || !sub.hasValue) return null;
    return sub.value as T?;
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
    } catch (e) {
      return CommandResult(
        commandId: command.id,
        success: false,
        message: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  // ── Lifecycle ──

  /// Establish transport connection and start heartbeat.
  Future<void> connect() async {
    _setState(DeviceConnectionState.connecting);
    try {
      await _connection.connect();
      _setState(DeviceConnectionState.connected);
      _startHeartbeat();
    } catch (e) {
      _setState(DeviceConnectionState.failed);
      rethrow;
    }
  }

  /// Tear down connection and stop heartbeat.
  Future<void> disconnect() async {
    _stopHeartbeat();
    await _connection.disconnect();
    _setState(DeviceConnectionState.disconnected);
  }

  /// Release all resources.
  Future<void> dispose() async {
    _stopHeartbeat();
    await _statusSub?.cancel();
    await _messageSub?.cancel();
    for (final sub in _fieldSubscriptions.values) {
      await sub.close();
    }
    _fieldSubscriptions.clear();
    await _connectionStateSubject.close();
  }

  // ── Heartbeat ──

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_connection.status == ConnectionStatus.connected) return;
      // Connection degraded — attempt recovery
      _setState(DeviceConnectionState.degraded);
      try {
        await _connection.connect();
        _setState(DeviceConnectionState.connected);
      } catch (_) {
        _setState(DeviceConnectionState.reconnecting);
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ── Connection listener ──

  void _listenToConnection() {
    _statusSub = _connection.statusStream.listen((status) {
      _setState(_mapConnectionStatus(status));
    });

    _messageSub = _connection.messageStream.listen((msg) {
      _dispatchMessage(msg);
    });
  }

  void _dispatchMessage(DeviceMessage msg) {
    final payload = msg.payload;

    // Dispatch to field-level subscriptions by prefix matching
    for (final entry in _fieldSubscriptions.entries) {
      final fieldPath = entry.key;
      final value = _extractNested(payload, fieldPath);
      if (value != null) {
        entry.value.add(value);
      }
    }
  }

  /// Extract a nested value from a JSON map by dotted path.
  /// E.g., `_extractNested({'temp': {'nozzle': 200}}, 'temp.nozzle')` → 200
  dynamic _extractNested(Map<String, dynamic> map, String path) {
    final parts = path.split('.');
    dynamic current = map;
    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  void _setState(DeviceConnectionState newState) {
    if (_connectionState == newState) return;
    _connectionState = newState;
    _connectionStateSubject.add(newState);
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
