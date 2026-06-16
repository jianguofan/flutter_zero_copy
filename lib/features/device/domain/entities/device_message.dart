import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_message.freezed.dart';
part 'device_message.g.dart';

/// A message received from or sent to a device.
///
/// MQTT topics become the [topic] field; payload is already decoded JSON.
@freezed
class DeviceMessage with _$DeviceMessage {
  const factory DeviceMessage({
    required String topic,
    required Map<String, dynamic> payload,
    required DateTime timestamp,
    String? messageId,
  }) = _DeviceMessage;

  factory DeviceMessage.fromJson(Map<String, dynamic> json) =>
      _$DeviceMessageFromJson(json);
}
