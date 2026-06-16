import 'dart:async';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';

/// Sealed class representing the lifecycle of a device session.
///
/// The compiler enforces exhaustive handling of all four states.
sealed class DeviceSessionState {
  const DeviceSessionState();
}

/// No device is currently active.
class DeviceSessionIdle extends DeviceSessionState {
  const DeviceSessionIdle();
}

/// A device activation is in progress.
class DeviceSessionActivating extends DeviceSessionState {
  final DeviceInfo info;
  const DeviceSessionActivating(this.info);
}

/// A device is active and ready.
class DeviceSessionActive extends DeviceSessionState {
  final IDeviceFacade device;
  const DeviceSessionActive(this.device);
}

/// An error occurred during activation or operation.
class DeviceSessionError extends DeviceSessionState {
  final DeviceInfo info;
  final Object error;
  final StackTrace? stackTrace;
  const DeviceSessionError(this.info, this.error, [this.stackTrace]);
}

/// Mediator that owns the "currently active device" concept.
///
/// Coordinates [IDeviceRegistry] lookups and [IDeviceFacade] lifecycle
/// to prevent two sources of truth for the active device.
abstract class IDeviceSession {
  /// Current session state.
  DeviceSessionState get state;

  /// Session state stream.
  Stream<DeviceSessionState> get stateStream;

  /// Activate a device by its registry ID.
  ///
  /// Atomic operation: lookup → connect → state transition → persist.
  Future<void> activate(String deviceId);

  /// Deactivate the current device and clear persisted state.
  Future<void> deactivate();

  /// The currently active device facade, or null.
  IDeviceFacade? get activeDevice;

  /// Convenience accessor for the active device's info.
  DeviceInfo? get activeDeviceInfo;
}
