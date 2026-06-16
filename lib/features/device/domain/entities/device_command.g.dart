// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DeviceCommandImpl _$$DeviceCommandImplFromJson(Map<String, dynamic> json) =>
    _$DeviceCommandImpl(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      method: json['method'] as String,
      params: json['params'] as Map<String, dynamic>?,
      priority:
          $enumDecodeNullable(_$CommandPriorityEnumMap, json['priority']) ??
              CommandPriority.normal,
      createdAt: DateTime.parse(json['createdAt'] as String),
      timeout: json['timeout'] == null
          ? null
          : Duration(microseconds: (json['timeout'] as num).toInt()),
    );

Map<String, dynamic> _$$DeviceCommandImplToJson(_$DeviceCommandImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'deviceId': instance.deviceId,
      'method': instance.method,
      'params': instance.params,
      'priority': _$CommandPriorityEnumMap[instance.priority]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'timeout': instance.timeout?.inMicroseconds,
    };

const _$CommandPriorityEnumMap = {
  CommandPriority.low: 'low',
  CommandPriority.normal: 'normal',
  CommandPriority.high: 'high',
  CommandPriority.critical: 'critical',
};

_$CommandResultImpl _$$CommandResultImplFromJson(Map<String, dynamic> json) =>
    _$CommandResultImpl(
      commandId: json['commandId'] as String,
      success: json['success'] as bool,
      message: json['message'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      errorCode: json['errorCode'] as String?,
      completedAt: DateTime.parse(json['completedAt'] as String),
    );

Map<String, dynamic> _$$CommandResultImplToJson(_$CommandResultImpl instance) =>
    <String, dynamic>{
      'commandId': instance.commandId,
      'success': instance.success,
      'message': instance.message,
      'data': instance.data,
      'errorCode': instance.errorCode,
      'completedAt': instance.completedAt.toIso8601String(),
    };
