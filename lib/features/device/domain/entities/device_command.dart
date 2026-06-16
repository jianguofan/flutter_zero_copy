import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_command.freezed.dart';
part 'device_command.g.dart';

/// Command priority determines queuing and pre-emption behaviour.
enum CommandPriority { low, normal, high, critical }

/// A command sent to a device (e.g., set temperature, pause print).
@freezed
class DeviceCommand with _$DeviceCommand {
  const factory DeviceCommand({
    required String id,
    required String deviceId,
    required String method,
    Map<String, dynamic>? params,
    @Default(CommandPriority.normal) CommandPriority priority,
    required DateTime createdAt,
    Duration? timeout,
  }) = _DeviceCommand;

  factory DeviceCommand.fromJson(Map<String, dynamic> json) =>
      _$DeviceCommandFromJson(json);
}

/// The result of executing a [DeviceCommand].
@freezed
class CommandResult with _$CommandResult {
  const factory CommandResult({
    required String commandId,
    required bool success,
    String? message,
    Map<String, dynamic>? data,
    String? errorCode,
    required DateTime completedAt,
  }) = _CommandResult;

  factory CommandResult.fromJson(Map<String, dynamic> json) =>
      _$CommandResultFromJson(json);
}
