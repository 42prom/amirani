// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trainer_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TrainerEntity {
  String get id => throw _privateConstructorUsedError;
  String get fullName => throw _privateConstructorUsedError;
  String? get specialization => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  bool get isAvailable => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $TrainerEntityCopyWith<TrainerEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TrainerEntityCopyWith<$Res> {
  factory $TrainerEntityCopyWith(
          TrainerEntity value, $Res Function(TrainerEntity) then) =
      _$TrainerEntityCopyWithImpl<$Res, TrainerEntity>;
  @useResult
  $Res call(
      {String id,
      String fullName,
      String? specialization,
      String? bio,
      String? avatarUrl,
      bool isAvailable});
}

/// @nodoc
class _$TrainerEntityCopyWithImpl<$Res, $Val extends TrainerEntity>
    implements $TrainerEntityCopyWith<$Res> {
  _$TrainerEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fullName = null,
    Object? specialization = freezed,
    Object? bio = freezed,
    Object? avatarUrl = freezed,
    Object? isAvailable = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      fullName: null == fullName
          ? _value.fullName
          : fullName // ignore: cast_nullable_to_non_nullable
              as String,
      specialization: freezed == specialization
          ? _value.specialization
          : specialization // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TrainerEntityImplCopyWith<$Res>
    implements $TrainerEntityCopyWith<$Res> {
  factory _$$TrainerEntityImplCopyWith(
          _$TrainerEntityImpl value, $Res Function(_$TrainerEntityImpl) then) =
      __$$TrainerEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String fullName,
      String? specialization,
      String? bio,
      String? avatarUrl,
      bool isAvailable});
}

/// @nodoc
class __$$TrainerEntityImplCopyWithImpl<$Res>
    extends _$TrainerEntityCopyWithImpl<$Res, _$TrainerEntityImpl>
    implements _$$TrainerEntityImplCopyWith<$Res> {
  __$$TrainerEntityImplCopyWithImpl(
      _$TrainerEntityImpl _value, $Res Function(_$TrainerEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fullName = null,
    Object? specialization = freezed,
    Object? bio = freezed,
    Object? avatarUrl = freezed,
    Object? isAvailable = null,
  }) {
    return _then(_$TrainerEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      fullName: null == fullName
          ? _value.fullName
          : fullName // ignore: cast_nullable_to_non_nullable
              as String,
      specialization: freezed == specialization
          ? _value.specialization
          : specialization // ignore: cast_nullable_to_non_nullable
              as String?,
      bio: freezed == bio
          ? _value.bio
          : bio // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$TrainerEntityImpl implements _TrainerEntity {
  const _$TrainerEntityImpl(
      {required this.id,
      required this.fullName,
      this.specialization,
      this.bio,
      this.avatarUrl,
      this.isAvailable = true});

  @override
  final String id;
  @override
  final String fullName;
  @override
  final String? specialization;
  @override
  final String? bio;
  @override
  final String? avatarUrl;
  @override
  @JsonKey()
  final bool isAvailable;

  @override
  String toString() {
    return 'TrainerEntity(id: $id, fullName: $fullName, specialization: $specialization, bio: $bio, avatarUrl: $avatarUrl, isAvailable: $isAvailable)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TrainerEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fullName, fullName) ||
                other.fullName == fullName) &&
            (identical(other.specialization, specialization) ||
                other.specialization == specialization) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, id, fullName, specialization, bio, avatarUrl, isAvailable);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TrainerEntityImplCopyWith<_$TrainerEntityImpl> get copyWith =>
      __$$TrainerEntityImplCopyWithImpl<_$TrainerEntityImpl>(this, _$identity);
}

abstract class _TrainerEntity implements TrainerEntity {
  const factory _TrainerEntity(
      {required final String id,
      required final String fullName,
      final String? specialization,
      final String? bio,
      final String? avatarUrl,
      final bool isAvailable}) = _$TrainerEntityImpl;

  @override
  String get id;
  @override
  String get fullName;
  @override
  String? get specialization;
  @override
  String? get bio;
  @override
  String? get avatarUrl;
  @override
  bool get isAvailable;
  @override
  @JsonKey(ignore: true)
  _$$TrainerEntityImplCopyWith<_$TrainerEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
