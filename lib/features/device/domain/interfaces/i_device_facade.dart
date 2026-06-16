import 'dart:async';
import 'package:flutter_zero_copy/features/device/domain/entities/device_command.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_message.dart';

/// Application-level connection state — 8-state machine for rich UX.
enum DeviceConnectionState {
  idle,
  connecting,
  handshaking,
  connected,
  degraded, // weak network / high latency
  reconnecting,
  disconnected,
  failed,
}

/// Read-only device abstraction exposed to the UI layer.
///
/// The UI never depends on concrete transport or protocol classes.
abstract class IDeviceFacade {
  /// Device identity and metadata.
  DeviceInfo get info;

  /// Current connection state.
  DeviceConnectionState get connectionState;

  /// Connection state stream.
  Stream<DeviceConnectionState> get connectionStateStream;

  /// Device event / notification stream.
  Stream<DeviceMessage> get messageStream;

  /// Subscribe to a specific field by dotted path (e.g., "temperature.nozzle").
  Stream<T> fieldStream<T>(String fieldPath);

  /// Get the current value of a specific field.
  T? getField<T>(String fieldPath);

  /// Send a command and wait for the result.
  Future<CommandResult> sendCommand(DeviceCommand command);
}
