// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trainer_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TrainerModel _$TrainerModelFromJson(Map<String, dynamic> json) {
  return _TrainerModel.fromJson(json);
}

/// @nodoc
mixin _$TrainerModel {
  String get id => throw _privateConstructorUsedError;
  String get fullName => throw _privateConstructorUsedError;
  String? get specialization => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  bool get isAvailable => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TrainerModelCopyWith<TrainerModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TrainerModelCopyWith<$Res> {
  factory $TrainerModelCopyWith(
          TrainerModel value, $Res Function(TrainerModel) then) =
      _$TrainerModelCopyWithImpl<$Res, TrainerModel>;
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
class _$TrainerModelCopyWithImpl<$Res, $Val extends TrainerModel>
    implements $TrainerModelCopyWith<$Res> {
  _$TrainerModelCopyWithImpl(this._value, this._then);

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
abstract class _$$TrainerModelImplCopyWith<$Res>
    implements $TrainerModelCopyWith<$Res> {
  factory _$$TrainerModelImplCopyWith(
          _$TrainerModelImpl value, $Res Function(_$TrainerModelImpl) then) =
      __$$TrainerModelImplCopyWithImpl<$Res>;
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
class __$$TrainerModelImplCopyWithImpl<$Res>
    extends _$TrainerModelCopyWithImpl<$Res, _$TrainerModelImpl>
    implements _$$TrainerModelImplCopyWith<$Res> {
  __$$TrainerModelImplCopyWithImpl(
      _$TrainerModelImpl _value, $Res Function(_$TrainerModelImpl) _then)
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
    return _then(_$TrainerModelImpl(
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
@JsonSerializable()
class _$TrainerModelImpl implements _TrainerModel {
  const _$TrainerModelImpl(
      {required this.id,
      required this.fullName,
      this.specialization,
      this.bio,
      this.avatarUrl,
      this.isAvailable = true});

  factory _$TrainerModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$TrainerModelImplFromJson(json);

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
    return 'TrainerModel(id: $id, fullName: $fullName, specialization: $specialization, bio: $bio, avatarUrl: $avatarUrl, isAvailable: $isAvailable)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TrainerModelImpl &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, fullName, specialization, bio, avatarUrl, isAvailable);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TrainerModelImplCopyWith<_$TrainerModelImpl> get copyWith =>
      __$$TrainerModelImplCopyWithImpl<_$TrainerModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TrainerModelImplToJson(
      this,
    );
  }
}

abstract class _TrainerModel implements TrainerModel {
  const factory _TrainerModel(
      {required final String id,
      required final String fullName,
      final String? specialization,
      final String? bio,
      final String? avatarUrl,
      final bool isAvailable}) = _$TrainerModelImpl;

  factory _TrainerModel.fromJson(Map<String, dynamic> json) =
      _$TrainerModelImpl.fromJson;

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
  _$$TrainerModelImplCopyWith<_$TrainerModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
