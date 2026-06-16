// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DeviceMessageImpl _$$DeviceMessageImplFromJson(Map<String, dynamic> json) =>
    _$DeviceMessageImpl(
      topic: json['topic'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      messageId: json['messageId'] as String?,
    );

Map<String, dynamic> _$$DeviceMessageImplToJson(_$DeviceMessageImpl instance) =>
    <String, dynamic>{
      'topic': instance.topic,
      'payload': instance.payload,
      'timestamp': instance.timestamp.toIso8601String(),
      'messageId': instance.messageId,
    };
