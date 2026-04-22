// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gym_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

GymModel _$GymModelFromJson(Map<String, dynamic> json) {
  return _GymModel.fromJson(json);
}

/// @nodoc
mixin _$GymModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  int get currentOccupancy => throw _privateConstructorUsedError;
  int get maxCapacity => throw _privateConstructorUsedError;
  List<TrainerModel> get trainers => throw _privateConstructorUsedError;
  RegistrationRequirementsEntity? get registrationRequirements =>
      throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $GymModelCopyWith<GymModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GymModelCopyWith<$Res> {
  factory $GymModelCopyWith(GymModel value, $Res Function(GymModel) then) =
      _$GymModelCopyWithImpl<$Res, GymModel>;
  @useResult
  $Res call(
      {String id,
      String name,
      String address,
      int currentOccupancy,
      int maxCapacity,
      List<TrainerModel> trainers,
      RegistrationRequirementsEntity? registrationRequirements});

  $RegistrationRequirementsEntityCopyWith<$Res>? get registrationRequirements;
}

/// @nodoc
class _$GymModelCopyWithImpl<$Res, $Val extends GymModel>
    implements $GymModelCopyWith<$Res> {
  _$GymModelCopyWithImpl(this._value, this._then);

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
              as List<TrainerModel>,
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
abstract class _$$GymModelImplCopyWith<$Res>
    implements $GymModelCopyWith<$Res> {
  factory _$$GymModelImplCopyWith(
          _$GymModelImpl value, $Res Function(_$GymModelImpl) then) =
      __$$GymModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String address,
      int currentOccupancy,
      int maxCapacity,
      List<TrainerModel> trainers,
      RegistrationRequirementsEntity? registrationRequirements});

  @override
  $RegistrationRequirementsEntityCopyWith<$Res>? get registrationRequirements;
}

/// @nodoc
class __$$GymModelImplCopyWithImpl<$Res>
    extends _$GymModelCopyWithImpl<$Res, _$GymModelImpl>
    implements _$$GymModelImplCopyWith<$Res> {
  __$$GymModelImplCopyWithImpl(
      _$GymModelImpl _value, $Res Function(_$GymModelImpl) _then)
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
    return _then(_$GymModelImpl(
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
              as List<TrainerModel>,
      registrationRequirements: freezed == registrationRequirements
          ? _value.registrationRequirements
          : registrationRequirements // ignore: cast_nullable_to_non_nullable
              as RegistrationRequirementsEntity?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GymModelImpl implements _GymModel {
  const _$GymModelImpl(
      {required this.id,
      required this.name,
      required this.address,
      required this.currentOccupancy,
      required this.maxCapacity,
      final List<TrainerModel> trainers = const [],
      this.registrationRequirements})
      : _trainers = trainers;

  factory _$GymModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$GymModelImplFromJson(json);

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
  final List<TrainerModel> _trainers;
  @override
  @JsonKey()
  List<TrainerModel> get trainers {
    if (_trainers is EqualUnmodifiableListView) return _trainers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_trainers);
  }

  @override
  final RegistrationRequirementsEntity? registrationRequirements;

  @override
  String toString() {
    return 'GymModel(id: $id, name: $name, address: $address, currentOccupancy: $currentOccupancy, maxCapacity: $maxCapacity, trainers: $trainers, registrationRequirements: $registrationRequirements)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GymModelImpl &&
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

  @JsonKey(ignore: true)
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
  _$$GymModelImplCopyWith<_$GymModelImpl> get copyWith =>
      __$$GymModelImplCopyWithImpl<_$GymModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GymModelImplToJson(
      this,
    );
  }
}

abstract class _GymModel implements GymModel {
  const factory _GymModel(
          {required final String id,
          required final String name,
          required final String address,
          required final int currentOccupancy,
          required final int maxCapacity,
          final List<TrainerModel> trainers,
          final RegistrationRequirementsEntity? registrationRequirements}) =
      _$GymModelImpl;

  factory _GymModel.fromJson(Map<String, dynamic> json) =
      _$GymModelImpl.fromJson;

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
  List<TrainerModel> get trainers;
  @override
  RegistrationRequirementsEntity? get registrationRequirements;
  @override
  @JsonKey(ignore: true)
  _$$GymModelImplCopyWith<_$GymModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
