// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DeviceMessage _$DeviceMessageFromJson(Map<String, dynamic> json) {
  return _DeviceMessage.fromJson(json);
}

/// @nodoc
mixin _$DeviceMessage {
  String get topic => throw _privateConstructorUsedError;
  Map<String, dynamic> get payload => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  String? get messageId => throw _privateConstructorUsedError;

  /// Serializes this DeviceMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DeviceMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeviceMessageCopyWith<DeviceMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceMessageCopyWith<$Res> {
  factory $DeviceMessageCopyWith(
          DeviceMessage value, $Res Function(DeviceMessage) then) =
      _$DeviceMessageCopyWithImpl<$Res, DeviceMessage>;
  @useResult
  $Res call(
      {String topic,
      Map<String, dynamic> payload,
      DateTime timestamp,
      String? messageId});
}

/// @nodoc
class _$DeviceMessageCopyWithImpl<$Res, $Val extends DeviceMessage>
    implements $DeviceMessageCopyWith<$Res> {
  _$DeviceMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeviceMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topic = null,
    Object? payload = null,
    Object? timestamp = null,
    Object? messageId = freezed,
  }) {
    return _then(_value.copyWith(
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      payload: null == payload
          ? _value.payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      messageId: freezed == messageId
          ? _value.messageId
          : messageId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DeviceMessageImplCopyWith<$Res>
    implements $DeviceMessageCopyWith<$Res> {
  factory _$$DeviceMessageImplCopyWith(
          _$DeviceMessageImpl value, $Res Function(_$DeviceMessageImpl) then) =
      __$$DeviceMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String topic,
      Map<String, dynamic> payload,
      DateTime timestamp,
      String? messageId});
}

/// @nodoc
class __$$DeviceMessageImplCopyWithImpl<$Res>
    extends _$DeviceMessageCopyWithImpl<$Res, _$DeviceMessageImpl>
    implements _$$DeviceMessageImplCopyWith<$Res> {
  __$$DeviceMessageImplCopyWithImpl(
      _$DeviceMessageImpl _value, $Res Function(_$DeviceMessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of DeviceMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topic = null,
    Object? payload = null,
    Object? timestamp = null,
    Object? messageId = freezed,
  }) {
    return _then(_$DeviceMessageImpl(
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      payload: null == payload
          ? _value._payload
          : payload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      messageId: freezed == messageId
          ? _value.messageId
          : messageId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DeviceMessageImpl implements _DeviceMessage {
  const _$DeviceMessageImpl(
      {required this.topic,
      required final Map<String, dynamic> payload,
      required this.timestamp,
      this.messageId})
      : _payload = payload;

  factory _$DeviceMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$DeviceMessageImplFromJson(json);

  @override
  final String topic;
  final Map<String, dynamic> _payload;
  @override
  Map<String, dynamic> get payload {
    if (_payload is EqualUnmodifiableMapView) return _payload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_payload);
  }

  @override
  final DateTime timestamp;
  @override
  final String? messageId;

  @override
  String toString() {
    return 'DeviceMessage(topic: $topic, payload: $payload, timestamp: $timestamp, messageId: $messageId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceMessageImpl &&
            (identical(other.topic, topic) || other.topic == topic) &&
            const DeepCollectionEquality().equals(other._payload, _payload) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.messageId, messageId) ||
                other.messageId == messageId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, topic,
      const DeepCollectionEquality().hash(_payload), timestamp, messageId);

  /// Create a copy of DeviceMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceMessageImplCopyWith<_$DeviceMessageImpl> get copyWith =>
      __$$DeviceMessageImplCopyWithImpl<_$DeviceMessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DeviceMessageImplToJson(
      this,
    );
  }
}

abstract class _DeviceMessage implements DeviceMessage {
  const factory _DeviceMessage(
      {required final String topic,
      required final Map<String, dynamic> payload,
      required final DateTime timestamp,
      final String? messageId}) = _$DeviceMessageImpl;

  factory _DeviceMessage.fromJson(Map<String, dynamic> json) =
      _$DeviceMessageImpl.fromJson;

  @override
  String get topic;
  @override
  Map<String, dynamic> get payload;
  @override
  DateTime get timestamp;
  @override
  String? get messageId;

  /// Create a copy of DeviceMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeviceMessageImplCopyWith<_$DeviceMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
