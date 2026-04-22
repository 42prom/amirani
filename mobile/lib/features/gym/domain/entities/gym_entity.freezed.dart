// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gym_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$GymEntity {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  int get currentOccupancy => throw _privateConstructorUsedError;
  int get maxCapacity => throw _privateConstructorUsedError;
  List<TrainerEntity> get trainers => throw _privateConstructorUsedError;
  RegistrationRequirementsEntity? get registrationRequirements =>
      throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $GymEntityCopyWith<GymEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GymEntityCopyWith<$Res> {
  factory $GymEntityCopyWith(GymEntity value, $Res Function(GymEntity) then) =
      _$GymEntityCopyWithImpl<$Res, GymEntity>;
  @useResult
  $Res call(
      {String id,
      String name,
      String address,
      int currentOccupancy,
      int maxCapacity,
      List<TrainerEntity> trainers,
      RegistrationRequirementsEntity? registrationRequirements});

  $RegistrationRequirementsEntityCopyWith<$Res>? get registrationRequirements;
}

/// @nodoc
class _$GymEntityCopyWithImpl<$Res, $Val extends GymEntity>
    implements $GymEntityCopyWith<$Res> {
  _$GymEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? address = null,
    Object? currentOccupancy = null,
    Object? maxCapacity = null,
    Object? trainers = null,
    Object? registrationRequirements = freezed,
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
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      currentOccupancy: null == currentOccupancy
          ? _value.currentOccupancy
          : currentOccupancy // ignore: cast_nullable_to_non_nullable
              as int,
      maxCapacity: null == maxCapacity
          ? _value.maxCapacity
          : maxCapacity // ignore: cast_nullable_to_non_nullable
              as int,
      trainers: null == trainers
          ? _value.trainers
          : trainers // ignore: cast_nullable_to_non_nullable
              as List<TrainerEntity>,
      registrationRequirements: freezed == registrationRequirements
          ? _value.registrationRequirements
          : registrationRequirements // ignore: cast_nullable_to_non_nullable
              as RegistrationRequirementsEntity?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $RegistrationRequirementsEntityCopyWith<$Res>? get registrationRequirements {
    if (_value.registrationRequirements == null) {
      return null;
    }

    return $RegistrationRequirementsEntityCopyWith<$Res>(
        _value.registrationRequirements!, (value) {
      return _then(_value.copyWith(registrationRequirements: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$GymEntityImplCopyWith<$Res>
    implements $GymEntityCopyWith<$Res> {
  factory _$$GymEntityImplCopyWith(
          _$GymEntityImpl value, $Res Function(_$GymEntityImpl) then) =
      __$$GymEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String address,
      int currentOccupancy,
      int maxCapacity,
      List<TrainerEntity> trainers,
      RegistrationRequirementsEntity? registrationRequirements});

  @override
  $RegistrationRequirementsEntityCopyWith<$Res>? get registrationRequirements;
}

/// @nodoc
class __$$GymEntityImplCopyWithImpl<$Res>
    extends _$GymEntityCopyWithImpl<$Res, _$GymEntityImpl>
    implements _$$GymEntityImplCopyWith<$Res> {
  __$$GymEntityImplCopyWithImpl(
      _$GymEntityImpl _value, $Res Function(_$GymEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? address = null,
    Object? currentOccupancy = null,
    Object? maxCapacity = null,
    Object? trainers = null,
    Object? registrationRequirements = freezed,
  }) {
    return _then(_$GymEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      currentOccupancy: null == currentOccupancy
          ? _value.currentOccupancy
          : currentOccupancy // ignore: cast_nullable_to_non_nullable
              as int,
      maxCapacity: null == maxCapacity
          ? _value.maxCapacity
          : maxCapacity // ignore: cast_nullable_to_non_nullable
              as int,
      trainers: null == trainers
          ? _value._trainers
          : trainers // ignore: cast_nullable_to_non_nullable
              as List<TrainerEntity>,
      registrationRequirements: freezed == registrationRequirements
          ? _value.registrationRequirements
          : registrationRequirements // ignore: cast_nullable_to_non_nullable
              as RegistrationRequirementsEntity?,
    ));
  }
}

/// @nodoc

class _$GymEntityImpl implements _GymEntity {
  const _$GymEntityImpl(
      {required this.id,
      required this.name,
      required this.address,
      required this.currentOccupancy,
      required this.maxCapacity,
      final List<TrainerEntity> trainers = const [],
      this.registrationRequirements})
      : _trainers = trainers;

  @override
  final String id;
  @override
  final String name;
  @override
  final String address;
  @override
  final int currentOccupancy;
  @override
  final int maxCapacity;
  final List<TrainerEntity> _trainers;
  @override
  @JsonKey()
  List<TrainerEntity> get trainers {
    if (_trainers is EqualUnmodifiableListView) return _trainers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_trainers);
  }

  @override
  final RegistrationRequirementsEntity? registrationRequirements;

  @override
  String toString() {
    return 'GymEntity(id: $id, name: $name, address: $address, currentOccupancy: $currentOccupancy, maxCapacity: $maxCapacity, trainers: $trainers, registrationRequirements: $registrationRequirements)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GymEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.currentOccupancy, currentOccupancy) ||
                other.currentOccupancy == currentOccupancy) &&
            (identical(other.maxCapacity, maxCapacity) ||
                other.maxCapacity == maxCapacity) &&
            const DeepCollectionEquality().equals(other._trainers, _trainers) &&
            (identical(
                    other.registrationRequirements, registrationRequirements) ||
                other.registrationRequirements == registrationRequirements));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      address,
      currentOccupancy,
      maxCapacity,
      const DeepCollectionEquality().hash(_trainers),
      registrationRequirements);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GymEntityImplCopyWith<_$GymEntityImpl> get copyWith =>
      __$$GymEntityImplCopyWithImpl<_$GymEntityImpl>(this, _$identity);
}

abstract class _GymEntity implements GymEntity {
  const factory _GymEntity(
          {required final String id,
          required final String name,
          required final String address,
          required final int currentOccupancy,
          required final int maxCapacity,
          final List<TrainerEntity> trainers,
          final RegistrationRequirementsEntity? registrationRequirements}) =
      _$GymEntityImpl;

  @override
  String get id;
  @override
  String get name;
  @override
  String get address;
  @override
  int get currentOccupancy;
  @override
  int get maxCapacity;
  @override
  List<TrainerEntity> get trainers;
  @override
  RegistrationRequirementsEntity? get registrationRequirements;
  @override
  @JsonKey(ignore: true)
  _$$GymEntityImplCopyWith<_$GymEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
