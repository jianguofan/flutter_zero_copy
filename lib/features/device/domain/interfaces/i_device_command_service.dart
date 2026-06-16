import 'package:flutter_zero_copy/features/device/domain/entities/device_command.dart';

/// Service for sending commands to the active device.
///
/// Handles queuing, cancellation, and timeout enforcement.
abstract class IDeviceCommandService {
  /// Send a command and wait for the result.
  Future<CommandResult> sendCommand(DeviceCommand command);

  /// Cancel a pending command by its ID.
  Future<void> cancelCommand(String commandId);

  /// Whether a command with the given ID is currently pending.
  bool isPending(String commandId);

  /// Number of pending commands.
  int get pendingCount;

  /// Dispose resources (e.g., pending Completers).
  void dispose();
}
