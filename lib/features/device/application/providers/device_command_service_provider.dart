import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_session_provider.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_command.dart';

/// Send a command to the active device and return the result.
///
/// Usage:
/// ```dart
/// final result = await ref.read(sendDeviceCommandProvider(DeviceCommand(...)).future);
/// ```
final sendDeviceCommandProvider =
    FutureProvider.family<CommandResult, DeviceCommand>((ref, command) async {
  final activeDevice = ref.watch(activeDeviceProvider);
  if (activeDevice == null) {
    return CommandResult(
      commandId: command.id,
      success: false,
      message: 'No active device',
      completedAt: DateTime.now(),
    );
  }
  return activeDevice.sendCommand(command);
});

/// Simple provider to check if a device is currently active.
final isDeviceActiveProvider = Provider<bool>((ref) {
  return ref.watch(activeDeviceProvider) != null;
});
