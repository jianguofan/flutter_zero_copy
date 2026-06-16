// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DeviceInfo _$DeviceInfoFromJson(Map<String, dynamic> json) {
  return _DeviceInfo.fromJson(json);
}

/// @nodoc
mixin _$DeviceInfo {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get sn => throw _privateConstructorUsedError;
  NetworkType get networkType => throw _privateConstructorUsedError;
  String? get ipAddress => throw _privateConstructorUsedError;
  String? get accessCode => throw _privateConstructorUsedError;
  String? get pinCode => throw _privateConstructorUsedError;
  String? get model => throw _privateConstructorUsedError;
  String? get firmwareVersion => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;
  DateTime? get lastSeen => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this DeviceInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeviceInfoCopyWith<DeviceInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceInfoCopyWith<$Res> {
  factory $DeviceInfoCopyWith(
          DeviceInfo value, $Res Function(DeviceInfo) then) =
      _$DeviceInfoCopyWithImpl<$Res, DeviceInfo>;
  @useResult
  $Res call(
      {String id,
      String name,
      String sn,
      NetworkType networkType,
      String? ipAddress,
      String? accessCode,
      String? pinCode,
      String? model,
      String? firmwareVersion,
      bool isOnline,
      DateTime? lastSeen,
      DateTime? createdAt});
}

/// @nodoc
class _$DeviceInfoCopyWithImpl<$Res, $Val extends DeviceInfo>
    implements $DeviceInfoCopyWith<$Res> {
  _$DeviceInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? sn = null,
    Object? networkType = null,
    Object? ipAddress = freezed,
    Object? accessCode = freezed,
    Object? pinCode = freezed,
    Object? model = freezed,
    Object? firmwareVersion = freezed,
    Object? isOnline = null,
    Object? lastSeen = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      sn: null == sn
          ? _value.sn
          : sn // ignore: cast_nullable_to_non_nullable
              as String,
      networkType: null == networkType
          ? _value.networkType
          : networkType // ignore: cast_nullable_to_non_nullable
              as NetworkType,
      ipAddress: freezed == ipAddress
          ? _value.ipAddress
          : ipAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      accessCode: freezed == accessCode
          ? _value.accessCode
          : accessCode // ignore: cast_nullable_to_non_nullable
              as String?,
      pinCode: freezed == pinCode
          ? _value.pinCode
          : pinCode // ignore: cast_nullable_to_non_nullable
              as String?,
      model: freezed == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String?,
      firmwareVersion: freezed == firmwareVersion
          ? _value.firmwareVersion
          : firmwareVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSeen: freezed == lastSeen
          ? _value.lastSeen
          : lastSeen // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DeviceInfoImplCopyWith<$Res>
    implements $DeviceInfoCopyWith<$Res> {
  factory _$$DeviceInfoImplCopyWith(
          _$DeviceInfoImpl value, $Res Function(_$DeviceInfoImpl) then) =
      __$$DeviceInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String sn,
      NetworkType networkType,
      String? ipAddress,
      String? accessCode,
      String? pinCode,
      String? model,
      String? firmwareVersion,
      bool isOnline,
      DateTime? lastSeen,
      DateTime? createdAt});
}

/// @nodoc
class __$$DeviceInfoImplCopyWithImpl<$Res>
    extends _$DeviceInfoCopyWithImpl<$Res, _$DeviceInfoImpl>
    implements _$$DeviceInfoImplCopyWith<$Res> {
  __$$DeviceInfoImplCopyWithImpl(
      _$DeviceInfoImpl _value, $Res Function(_$DeviceInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of DeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? sn = null,
    Object? networkType = null,
    Object? ipAddress = freezed,
    Object? accessCode = freezed,
    Object? pinCode = freezed,
    Object? model = freezed,
    Object? firmwareVersion = freezed,
    Object? isOnline = null,
    Object? lastSeen = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_$DeviceInfoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      sn: null == sn
          ? _value.sn
          : sn // ignore: cast_nullable_to_non_nullable
              as String,
      networkType: null == networkType
          ? _value.networkType
          : networkType // ignore: cast_nullable_to_non_nullable
              as NetworkType,
      ipAddress: freezed == ipAddress
          ? _value.ipAddress
          : ipAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      accessCode: freezed == accessCode
          ? _value.accessCode
          : accessCode // ignore: cast_nullable_to_non_nullable
              as String?,
      pinCode: freezed == pinCode
          ? _value.pinCode
          : pinCode // ignore: cast_nullable_to_non_nullable
              as String?,
      model: freezed == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String?,
      firmwareVersion: freezed == firmwareVersion
          ? _value.firmwareVersion
          : firmwareVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSeen: freezed == lastSeen
          ? _value.lastSeen
          : lastSeen // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DeviceInfoImpl implements _DeviceInfo {
  const _$DeviceInfoImpl(
      {required this.id,
      required this.name,
      required this.sn,
      this.networkType = NetworkType.lan,
      this.ipAddress,
      this.accessCode,
      this.pinCode,
      this.model,
      this.firmwareVersion,
      this.isOnline = false,
      this.lastSeen,
      this.createdAt});

  factory _$DeviceInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$DeviceInfoImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String sn;
  @override
  @JsonKey()
  final NetworkType networkType;
  @override
  final String? ipAddress;
  @override
  final String? accessCode;
  @override
  final String? pinCode;
  @override
  final String? model;
  @override
  final String? firmwareVersion;
  @override
  @JsonKey()
  final bool isOnline;
  @override
  final DateTime? lastSeen;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'DeviceInfo(id: $id, name: $name, sn: $sn, networkType: $networkType, ipAddress: $ipAddress, accessCode: $accessCode, pinCode: $pinCode, model: $model, firmwareVersion: $firmwareVersion, isOnline: $isOnline, lastSeen: $lastSeen, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceInfoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.sn, sn) || other.sn == sn) &&
            (identical(other.networkType, networkType) ||
                other.networkType == networkType) &&
            (identical(other.ipAddress, ipAddress) ||
                other.ipAddress == ipAddress) &&
            (identical(other.accessCode, accessCode) ||
                other.accessCode == accessCode) &&
            (identical(other.pinCode, pinCode) || other.pinCode == pinCode) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.firmwareVersion, firmwareVersion) ||
                other.firmwareVersion == firmwareVersion) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.lastSeen, lastSeen) ||
                other.lastSeen == lastSeen) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      sn,
      networkType,
      ipAddress,
      accessCode,
      pinCode,
      model,
      firmwareVersion,
      isOnline,
      lastSeen,
      createdAt);

  /// Create a copy of DeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceInfoImplCopyWith<_$DeviceInfoImpl> get copyWith =>
      __$$DeviceInfoImplCopyWithImpl<_$DeviceInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DeviceInfoImplToJson(
      this,
    );
  }
}

abstract class _DeviceInfo implements DeviceInfo {
  const factory _DeviceInfo(
      {required final String id,
      required final String name,
      required final String sn,
      final NetworkType networkType,
      final String? ipAddress,
      final String? accessCode,
      final String? pinCode,
      final String? model,
      final String? firmwareVersion,
      final bool isOnline,
      final DateTime? lastSeen,
      final DateTime? createdAt}) = _$DeviceInfoImpl;

  factory _DeviceInfo.fromJson(Map<String, dynamic> json) =
      _$DeviceInfoImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get sn;
  @override
  NetworkType get networkType;
  @override
  String? get ipAddress;
  @override
  String? get accessCode;
  @override
  String? get pinCode;
  @override
  String? get model;
  @override
  String? get firmwareVersion;
  @override
  bool get isOnline;
  @override
  DateTime? get lastSeen;
  @override
  DateTime? get createdAt;

  /// Create a copy of DeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeviceInfoImplCopyWith<_$DeviceInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
