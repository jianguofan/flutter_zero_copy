// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_command.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DeviceCommand _$DeviceCommandFromJson(Map<String, dynamic> json) {
  return _DeviceCommand.fromJson(json);
}

/// @nodoc
mixin _$DeviceCommand {
  String get id => throw _privateConstructorUsedError;
  String get deviceId => throw _privateConstructorUsedError;
  String get method => throw _privateConstructorUsedError;
  Map<String, dynamic>? get params => throw _privateConstructorUsedError;
  CommandPriority get priority => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  Duration? get timeout => throw _privateConstructorUsedError;

  /// Serializes this DeviceCommand to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DeviceCommand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeviceCommandCopyWith<DeviceCommand> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceCommandCopyWith<$Res> {
  factory $DeviceCommandCopyWith(
          DeviceCommand value, $Res Function(DeviceCommand) then) =
      _$DeviceCommandCopyWithImpl<$Res, DeviceCommand>;
  @useResult
  $Res call(
      {String id,
      String deviceId,
      String method,
      Map<String, dynamic>? params,
      CommandPriority priority,
      DateTime createdAt,
      Duration? timeout});
}

/// @nodoc
class _$DeviceCommandCopyWithImpl<$Res, $Val extends DeviceCommand>
    implements $DeviceCommandCopyWith<$Res> {
  _$DeviceCommandCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeviceCommand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? deviceId = null,
    Object? method = null,
    Object? params = freezed,
    Object? priority = null,
    Object? createdAt = null,
    Object? timeout = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      deviceId: null == deviceId
          ? _value.deviceId
          : deviceId // ignore: cast_nullable_to_non_nullable
              as String,
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
      params: freezed == params
          ? _value.params
          : params // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as CommandPriority,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timeout: freezed == timeout
          ? _value.timeout
          : timeout // ignore: cast_nullable_to_non_nullable
              as Duration?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DeviceCommandImplCopyWith<$Res>
    implements $DeviceCommandCopyWith<$Res> {
  factory _$$DeviceCommandImplCopyWith(
          _$DeviceCommandImpl value, $Res Function(_$DeviceCommandImpl) then) =
      __$$DeviceCommandImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String deviceId,
      String method,
      Map<String, dynamic>? params,
      CommandPriority priority,
      DateTime createdAt,
      Duration? timeout});
}

/// @nodoc
class __$$DeviceCommandImplCopyWithImpl<$Res>
    extends _$DeviceCommandCopyWithImpl<$Res, _$DeviceCommandImpl>
    implements _$$DeviceCommandImplCopyWith<$Res> {
  __$$DeviceCommandImplCopyWithImpl(
      _$DeviceCommandImpl _value, $Res Function(_$DeviceCommandImpl) _then)
      : super(_value, _then);

  /// Create a copy of DeviceCommand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? deviceId = null,
    Object? method = null,
    Object? params = freezed,
    Object? priority = null,
    Object? createdAt = null,
    Object? timeout = freezed,
  }) {
    return _then(_$DeviceCommandImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      deviceId: null == deviceId
          ? _value.deviceId
          : deviceId // ignore: cast_nullable_to_non_nullable
              as String,
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
      params: freezed == params
          ? _value._params
          : params // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as CommandPriority,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timeout: freezed == timeout
          ? _value.timeout
          : timeout // ignore: cast_nullable_to_non_nullable
              as Duration?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DeviceCommandImpl implements _DeviceCommand {
  const _$DeviceCommandImpl(
      {required this.id,
      required this.deviceId,
      required this.method,
      final Map<String, dynamic>? params,
      this.priority = CommandPriority.normal,
      required this.createdAt,
      this.timeout})
      : _params = params;

  factory _$DeviceCommandImpl.fromJson(Map<String, dynamic> json) =>
      _$$DeviceCommandImplFromJson(json);

  @override
  final String id;
  @override
  final String deviceId;
  @override
  final String method;
  final Map<String, dynamic>? _params;
  @override
  Map<String, dynamic>? get params {
    final value = _params;
    if (value == null) return null;
    if (_params is EqualUnmodifiableMapView) return _params;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final CommandPriority priority;
  @override
  final DateTime createdAt;
  @override
  final Duration? timeout;

  @override
  String toString() {
    return 'DeviceCommand(id: $id, deviceId: $deviceId, method: $method, params: $params, priority: $priority, createdAt: $createdAt, timeout: $timeout)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceCommandImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.method, method) || other.method == method) &&
            const DeepCollectionEquality().equals(other._params, _params) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.timeout, timeout) || other.timeout == timeout));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      deviceId,
      method,
      const DeepCollectionEquality().hash(_params),
      priority,
      createdAt,
      timeout);

  /// Create a copy of DeviceCommand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceCommandImplCopyWith<_$DeviceCommandImpl> get copyWith =>
      __$$DeviceCommandImplCopyWithImpl<_$DeviceCommandImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DeviceCommandImplToJson(
      this,
    );
  }
}

abstract class _DeviceCommand implements DeviceCommand {
  const factory _DeviceCommand(
      {required final String id,
      required final String deviceId,
      required final String method,
      final Map<String, dynamic>? params,
      final CommandPriority priority,
      required final DateTime createdAt,
      final Duration? timeout}) = _$DeviceCommandImpl;

  factory _DeviceCommand.fromJson(Map<String, dynamic> json) =
      _$DeviceCommandImpl.fromJson;

  @override
  String get id;
  @override
  String get deviceId;
  @override
  String get method;
  @override
  Map<String, dynamic>? get params;
  @override
  CommandPriority get priority;
  @override
  DateTime get createdAt;
  @override
  Duration? get timeout;

  /// Create a copy of DeviceCommand
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeviceCommandImplCopyWith<_$DeviceCommandImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CommandResult _$CommandResultFromJson(Map<String, dynamic> json) {
  return _CommandResult.fromJson(json);
}

/// @nodoc
mixin _$CommandResult {
  String get commandId => throw _privateConstructorUsedError;
  bool get success => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  Map<String, dynamic>? get data => throw _privateConstructorUsedError;
  String? get errorCode => throw _privateConstructorUsedError;
  DateTime get completedAt => throw _privateConstructorUsedError;

  /// Serializes this CommandResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CommandResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CommandResultCopyWith<CommandResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CommandResultCopyWith<$Res> {
  factory $CommandResultCopyWith(
          CommandResult value, $Res Function(CommandResult) then) =
      _$CommandResultCopyWithImpl<$Res, CommandResult>;
  @useResult
  $Res call(
      {String commandId,
      bool success,
      String? message,
      Map<String, dynamic>? data,
      String? errorCode,
      DateTime completedAt});
}

/// @nodoc
class _$CommandResultCopyWithImpl<$Res, $Val extends CommandResult>
    implements $CommandResultCopyWith<$Res> {
  _$CommandResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CommandResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? commandId = null,
    Object? success = null,
    Object? message = freezed,
    Object? data = freezed,
    Object? errorCode = freezed,
    Object? completedAt = null,
  }) {
    return _then(_value.copyWith(
      commandId: null == commandId
          ? _value.commandId
          : commandId // ignore: cast_nullable_to_non_nullable
              as String,
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      errorCode: freezed == errorCode
          ? _value.errorCode
          : errorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      completedAt: null == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CommandResultImplCopyWith<$Res>
    implements $CommandResultCopyWith<$Res> {
  factory _$$CommandResultImplCopyWith(
          _$CommandResultImpl value, $Res Function(_$CommandResultImpl) then) =
      __$$CommandResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String commandId,
      bool success,
      String? message,
      Map<String, dynamic>? data,
      String? errorCode,
      DateTime completedAt});
}

/// @nodoc
class __$$CommandResultImplCopyWithImpl<$Res>
    extends _$CommandResultCopyWithImpl<$Res, _$CommandResultImpl>
    implements _$$CommandResultImplCopyWith<$Res> {
  __$$CommandResultImplCopyWithImpl(
      _$CommandResultImpl _value, $Res Function(_$CommandResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of CommandResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? commandId = null,
    Object? success = null,
    Object? message = freezed,
    Object? data = freezed,
    Object? errorCode = freezed,
    Object? completedAt = null,
  }) {
    return _then(_$CommandResultImpl(
      commandId: null == commandId
          ? _value.commandId
          : commandId // ignore: cast_nullable_to_non_nullable
              as String,
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      data: freezed == data
          ? _value._data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      errorCode: freezed == errorCode
          ? _value.errorCode
          : errorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      completedAt: null == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CommandResultImpl implements _CommandResult {
  const _$CommandResultImpl(
      {required this.commandId,
      required this.success,
      this.message,
      final Map<String, dynamic>? data,
      this.errorCode,
      required this.completedAt})
      : _data = data;

  factory _$CommandResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$CommandResultImplFromJson(json);

  @override
  final String commandId;
  @override
  final bool success;
  @override
  final String? message;
  final Map<String, dynamic>? _data;
  @override
  Map<String, dynamic>? get data {
    final value = _data;
    if (value == null) return null;
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? errorCode;
  @override
  final DateTime completedAt;

  @override
  String toString() {
    return 'CommandResult(commandId: $commandId, success: $success, message: $message, data: $data, errorCode: $errorCode, completedAt: $completedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CommandResultImpl &&
            (identical(other.commandId, commandId) ||
                other.commandId == commandId) &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other._data, _data) &&
            (identical(other.errorCode, errorCode) ||
                other.errorCode == errorCode) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, commandId, success, message,
      const DeepCollectionEquality().hash(_data), errorCode, completedAt);

  /// Create a copy of CommandResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CommandResultImplCopyWith<_$CommandResultImpl> get copyWith =>
      __$$CommandResultImplCopyWithImpl<_$CommandResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CommandResultImplToJson(
      this,
    );
  }
}

abstract class _CommandResult implements CommandResult {
  const factory _CommandResult(
      {required final String commandId,
      required final bool success,
      final String? message,
      final Map<String, dynamic>? data,
      final String? errorCode,
      required final DateTime completedAt}) = _$CommandResultImpl;

  factory _CommandResult.fromJson(Map<String, dynamic> json) =
      _$CommandResultImpl.fromJson;

  @override
  String get commandId;
  @override
  bool get success;
  @override
  String? get message;
  @override
  Map<String, dynamic>? get data;
  @override
  String? get errorCode;
  @override
  DateTime get completedAt;

  /// Create a copy of CommandResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CommandResultImplCopyWith<_$CommandResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
