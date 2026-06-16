import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_info.freezed.dart';
part 'device_info.g.dart';

/// Network type used to connect to a device.
enum NetworkType { lan, wan }

/// Identifies and describes a Snapmaker 3D printer.
///
/// Immutable data class — use [copyWith] for modifications.
@freezed
class DeviceInfo with _$DeviceInfo {
  const factory DeviceInfo({
    required String id,
    required String name,
    required String sn,
    @Default(NetworkType.lan) NetworkType networkType,
    String? ipAddress,
    String? accessCode,
    String? pinCode,
    String? model,
    String? firmwareVersion,
    @Default(false) bool isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) = _DeviceInfo;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoFromJson(json);
}
