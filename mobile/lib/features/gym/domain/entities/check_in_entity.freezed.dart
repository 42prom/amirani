// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'check_in_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$CheckInEntity {
  String get id => throw _privateConstructorUsedError;
  String get gymId => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  bool get isSuccess => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $CheckInEntityCopyWith<CheckInEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckInEntityCopyWith<$Res> {
  factory $CheckInEntityCopyWith(
          CheckInEntity value, $Res Function(CheckInEntity) then) =
      _$CheckInEntityCopyWithImpl<$Res, CheckInEntity>;
  @useResult
  $Res call(
      {String id,
      String gymId,
      DateTime timestamp,
      bool isSuccess,
      String message});
}

/// @nodoc
class _$CheckInEntityCopyWithImpl<$Res, $Val extends CheckInEntity>
    implements $CheckInEntityCopyWith<$Res> {
  _$CheckInEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gymId = null,
    Object? timestamp = null,
    Object? isSuccess = null,
    Object? message = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      gymId: null == gymId
          ? _value.gymId
          : gymId // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isSuccess: null == isSuccess
          ? _value.isSuccess
          : isSuccess // ignore: cast_nullable_to_non_nullable
              as bool,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CheckInEntityImplCopyWith<$Res>
    implements $CheckInEntityCopyWith<$Res> {
  factory _$$CheckInEntityImplCopyWith(
          _$CheckInEntityImpl value, $Res Function(_$CheckInEntityImpl) then) =
      __$$CheckInEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String gymId,
      DateTime timestamp,
      bool isSuccess,
      String message});
}

/// @nodoc
class __$$CheckInEntityImplCopyWithImpl<$Res>
    extends _$CheckInEntityCopyWithImpl<$Res, _$CheckInEntityImpl>
    implements _$$CheckInEntityImplCopyWith<$Res> {
  __$$CheckInEntityImplCopyWithImpl(
      _$CheckInEntityImpl _value, $Res Function(_$CheckInEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gymId = null,
    Object? timestamp = null,
    Object? isSuccess = null,
    Object? message = null,
  }) {
    return _then(_$CheckInEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      gymId: null == gymId
          ? _value.gymId
          : gymId // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isSuccess: null == isSuccess
          ? _value.isSuccess
          : isSuccess // ignore: cast_nullable_to_non_nullable
              as bool,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$CheckInEntityImpl implements _CheckInEntity {
  const _$CheckInEntityImpl(
      {required this.id,
      required this.gymId,
      required this.timestamp,
      required this.isSuccess,
      required this.message});

  @override
  final String id;
  @override
  final String gymId;
  @override
  final DateTime timestamp;
  @override
  final bool isSuccess;
  @override
  final String message;

  @override
  String toString() {
    return 'CheckInEntity(id: $id, gymId: $gymId, timestamp: $timestamp, isSuccess: $isSuccess, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckInEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.gymId, gymId) || other.gymId == gymId) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.isSuccess, isSuccess) ||
                other.isSuccess == isSuccess) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, gymId, timestamp, isSuccess, message);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckInEntityImplCopyWith<_$CheckInEntityImpl> get copyWith =>
      __$$CheckInEntityImplCopyWithImpl<_$CheckInEntityImpl>(this, _$identity);
}

abstract class _CheckInEntity implements CheckInEntity {
  const factory _CheckInEntity(
      {required final String id,
      required final String gymId,
      required final DateTime timestamp,
      required final bool isSuccess,
      required final String message}) = _$CheckInEntityImpl;

  @override
  String get id;
  @override
  String get gymId;
  @override
  DateTime get timestamp;
  @override
  bool get isSuccess;
  @override
  String get message;
  @override
  @JsonKey(ignore: true)
  _$$CheckInEntityImplCopyWith<_$CheckInEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
