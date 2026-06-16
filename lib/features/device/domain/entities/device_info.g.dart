// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DeviceInfoImpl _$$DeviceInfoImplFromJson(Map<String, dynamic> json) =>
    _$DeviceInfoImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      sn: json['sn'] as String,
      networkType:
          $enumDecodeNullable(_$NetworkTypeEnumMap, json['networkType']) ??
              NetworkType.lan,
      ipAddress: json['ipAddress'] as String?,
      accessCode: json['accessCode'] as String?,
      pinCode: json['pinCode'] as String?,
      model: json['model'] as String?,
      firmwareVersion: json['firmwareVersion'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$DeviceInfoImplToJson(_$DeviceInfoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'sn': instance.sn,
      'networkType': _$NetworkTypeEnumMap[instance.networkType]!,
      'ipAddress': instance.ipAddress,
      'accessCode': instance.accessCode,
      'pinCode': instance.pinCode,
      'model': instance.model,
      'firmwareVersion': instance.firmwareVersion,
      'isOnline': instance.isOnline,
      'lastSeen': instance.lastSeen?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$NetworkTypeEnumMap = {
  NetworkType.lan: 'lan',
  NetworkType.wan: 'wan',
};
