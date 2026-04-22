// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserEntity _$UserEntityFromJson(Map<String, dynamic> json) {
  return _UserEntity.fromJson(json);
}

/// @nodoc
mixin _$UserEntity {
  String get id => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  String? get managedGymId => throw _privateConstructorUsedError;
  String? get phoneNumber => throw _privateConstructorUsedError;
  String? get fullName => throw _privateConstructorUsedError;
  String? get firstName => throw _privateConstructorUsedError;
  String? get lastName => throw _privateConstructorUsedError;
  String? get gender => throw _privateConstructorUsedError;
  String? get dob => throw _privateConstructorUsedError;
  String? get weight => throw _privateConstructorUsedError;
  String? get height => throw _privateConstructorUsedError;
  String? get medicalConditions => throw _privateConstructorUsedError;
  bool get noMedicalConditions => throw _privateConstructorUsedError;
  String? get personalNumber => throw _privateConstructorUsedError;
  String? get address => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String? get idPhotoUrl => throw _privateConstructorUsedError;
  double? get targetWeightKg => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserEntityCopyWith<UserEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserEntityCopyWith<$Res> {
  factory $UserEntityCopyWith(
          UserEntity value, $Res Function(UserEntity) then) =
      _$UserEntityCopyWithImpl<$Res, UserEntity>;
  @useResult
  $Res call(
      {String id,
      String email,
      String role,
      String? managedGymId,
      String? phoneNumber,
      String? fullName,
      String? firstName,
      String? lastName,
      String? gender,
      String? dob,
      String? weight,
      String? height,
      String? medicalConditions,
      bool noMedicalConditions,
      String? personalNumber,
      String? address,
      String? avatarUrl,
      String? idPhotoUrl,
      double? targetWeightKg});
}

/// @nodoc
class _$UserEntityCopyWithImpl<$Res, $Val extends UserEntity>
    implements $UserEntityCopyWith<$Res> {
  _$UserEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? role = null,
    Object? managedGymId = freezed,
    Object? phoneNumber = freezed,
    Object? fullName = freezed,
    Object? firstName = freezed,
    Object? lastName = freezed,
    Object? gender = freezed,
    Object? dob = freezed,
    Object? weight = freezed,
    Object? height = freezed,
    Object? medicalConditions = freezed,
    Object? noMedicalConditions = null,
    Object? personalNumber = freezed,
    Object? address = freezed,
    Object? avatarUrl = freezed,
    Object? idPhotoUrl = freezed,
    Object? targetWeightKg = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      managedGymId: freezed == managedGymId
          ? _value.managedGymId
          : managedGymId // ignore: cast_nullable_to_non_nullable
              as String?,
      phoneNumber: freezed == phoneNumber
          ? _value.phoneNumber
          : phoneNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      fullName: freezed == fullName
          ? _value.fullName
          : fullName // ignore: cast_nullable_to_non_nullable
              as String?,
      firstName: freezed == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String?,
      lastName: freezed == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String?,
      gender: freezed == gender
          ? _value.gender
          : gender // ignore: cast_nullable_to_non_nullable
              as String?,
      dob: freezed == dob
          ? _value.dob
          : dob // ignore: cast_nullable_to_non_nullable
              as String?,
      weight: freezed == weight
          ? _value.weight
          : weight // ignore: cast_nullable_to_non_nullable
              as String?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as String?,
      medicalConditions: freezed == medicalConditions
          ? _value.medicalConditions
          : medicalConditions // ignore: cast_nullable_to_non_nullable
              as String?,
      noMedicalConditions: null == noMedicalConditions
          ? _value.noMedicalConditions
          : noMedicalConditions // ignore: cast_nullable_to_non_nullable
              as bool,
      personalNumber: freezed == personalNumber
          ? _value.personalNumber
          : personalNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      idPhotoUrl: freezed == idPhotoUrl
          ? _value.idPhotoUrl
          : idPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      targetWeightKg: freezed == targetWeightKg
          ? _value.targetWeightKg
          : targetWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserEntityImplCopyWith<$Res>
    implements $UserEntityCopyWith<$Res> {
  factory _$$UserEntityImplCopyWith(
          _$UserEntityImpl value, $Res Function(_$UserEntityImpl) then) =
      __$$UserEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String email,
      String role,
      String? managedGymId,
      String? phoneNumber,
      String? fullName,
      String? firstName,
      String? lastName,
      String? gender,
      String? dob,
      String? weight,
      String? height,
      String? medicalConditions,
      bool noMedicalConditions,
      String? personalNumber,
      String? address,
      String? avatarUrl,
      String? idPhotoUrl,
      double? targetWeightKg});
}

/// @nodoc
class __$$UserEntityImplCopyWithImpl<$Res>
    extends _$UserEntityCopyWithImpl<$Res, _$UserEntityImpl>
    implements _$$UserEntityImplCopyWith<$Res> {
  __$$UserEntityImplCopyWithImpl(
      _$UserEntityImpl _value, $Res Function(_$UserEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? role = null,
    Object? managedGymId = freezed,
    Object? phoneNumber = freezed,
    Object? fullName = freezed,
    Object? firstName = freezed,
    Object? lastName = freezed,
    Object? gender = freezed,
    Object? dob = freezed,
    Object? weight = freezed,
    Object? height = freezed,
    Object? medicalConditions = freezed,
    Object? noMedicalConditions = null,
    Object? personalNumber = freezed,
    Object? address = freezed,
    Object? avatarUrl = freezed,
    Object? idPhotoUrl = freezed,
    Object? targetWeightKg = freezed,
  }) {
    return _then(_$UserEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      managedGymId: freezed == managedGymId
          ? _value.managedGymId
          : managedGymId // ignore: cast_nullable_to_non_nullable
              as String?,
      phoneNumber: freezed == phoneNumber
          ? _value.phoneNumber
          : phoneNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      fullName: freezed == fullName
          ? _value.fullName
          : fullName // ignore: cast_nullable_to_non_nullable
              as String?,
      firstName: freezed == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String?,
      lastName: freezed == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String?,
      gender: freezed == gender
          ? _value.gender
          : gender // ignore: cast_nullable_to_non_nullable
              as String?,
      dob: freezed == dob
          ? _value.dob
          : dob // ignore: cast_nullable_to_non_nullable
              as String?,
      weight: freezed == weight
          ? _value.weight
          : weight // ignore: cast_nullable_to_non_nullable
              as String?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as String?,
      medicalConditions: freezed == medicalConditions
          ? _value.medicalConditions
          : medicalConditions // ignore: cast_nullable_to_non_nullable
              as String?,
      noMedicalConditions: null == noMedicalConditions
          ? _value.noMedicalConditions
          : noMedicalConditions // ignore: cast_nullable_to_non_nullable
              as bool,
      personalNumber: freezed == personalNumber
          ? _value.personalNumber
          : personalNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      address: freezed == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      idPhotoUrl: freezed == idPhotoUrl
          ? _value.idPhotoUrl
          : idPhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      targetWeightKg: freezed == targetWeightKg
          ? _value.targetWeightKg
          : targetWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserEntityImpl implements _UserEntity {
  const _$UserEntityImpl(
      {required this.id,
      required this.email,
      required this.role,
      this.managedGymId,
      this.phoneNumber,
      this.fullName,
      this.firstName,
      this.lastName,
      this.gender,
      this.dob,
      this.weight,
      this.height,
      this.medicalConditions,
      this.noMedicalConditions = false,
      this.personalNumber,
      this.address,
      this.avatarUrl,
      this.idPhotoUrl,
      this.targetWeightKg});

  factory _$UserEntityImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserEntityImplFromJson(json);

  @override
  final String id;
  @override
  final String email;
  @override
  final String role;
  @override
  final String? managedGymId;
  @override
  final String? phoneNumber;
  @override
  final String? fullName;
  @override
  final String? firstName;
  @override
  final String? lastName;
  @override
  final String? gender;
  @override
  final String? dob;
  @override
  final String? weight;
  @override
  final String? height;
  @override
  final String? medicalConditions;
  @override
  @JsonKey()
  final bool noMedicalConditions;
  @override
  final String? personalNumber;
  @override
  final String? address;
  @override
  final String? avatarUrl;
  @override
  final String? idPhotoUrl;
  @override
  final double? targetWeightKg;

  @override
  String toString() {
    return 'UserEntity(id: $id, email: $email, role: $role, managedGymId: $managedGymId, phoneNumber: $phoneNumber, fullName: $fullName, firstName: $firstName, lastName: $lastName, gender: $gender, dob: $dob, weight: $weight, height: $height, medicalConditions: $medicalConditions, noMedicalConditions: $noMedicalConditions, personalNumber: $personalNumber, address: $address, avatarUrl: $avatarUrl, idPhotoUrl: $idPhotoUrl, targetWeightKg: $targetWeightKg)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.managedGymId, managedGymId) ||
                other.managedGymId == managedGymId) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.fullName, fullName) ||
                other.fullName == fullName) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.dob, dob) || other.dob == dob) &&
            (identical(other.weight, weight) || other.weight == weight) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.medicalConditions, medicalConditions) ||
                other.medicalConditions == medicalConditions) &&
            (identical(other.noMedicalConditions, noMedicalConditions) ||
                other.noMedicalConditions == noMedicalConditions) &&
            (identical(other.personalNumber, personalNumber) ||
                other.personalNumber == personalNumber) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.idPhotoUrl, idPhotoUrl) ||
                other.idPhotoUrl == idPhotoUrl) &&
            (identical(other.targetWeightKg, targetWeightKg) ||
                other.targetWeightKg == targetWeightKg));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        email,
        role,
        managedGymId,
        phoneNumber,
        fullName,
        firstName,
        lastName,
        gender,
        dob,
        weight,
        height,
        medicalConditions,
        noMedicalConditions,
        personalNumber,
        address,
        avatarUrl,
        idPhotoUrl,
        targetWeightKg
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserEntityImplCopyWith<_$UserEntityImpl> get copyWith =>
      __$$UserEntityImplCopyWithImpl<_$UserEntityImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserEntityImplToJson(
      this,
    );
  }
}

abstract class _UserEntity implements UserEntity {
  const factory _UserEntity(
      {required final String id,
      required final String email,
      required final String role,
      final String? managedGymId,
      final String? phoneNumber,
      final String? fullName,
      final String? firstName,
      final String? lastName,
      final String? gender,
      final String? dob,
      final String? weight,
      final String? height,
      final String? medicalConditions,
      final bool noMedicalConditions,
      final String? personalNumber,
      final String? address,
      final String? avatarUrl,
      final String? idPhotoUrl,
      final double? targetWeightKg}) = _$UserEntityImpl;

  factory _UserEntity.fromJson(Map<String, dynamic> json) =
      _$UserEntityImpl.fromJson;

  @override
  String get id;
  @override
  String get email;
  @override
  String get role;
  @override
  String? get managedGymId;
  @override
  String? get phoneNumber;
  @override
  String? get fullName;
  @override
  String? get firstName;
  @override
  String? get lastName;
  @override
  String? get gender;
  @override
  String? get dob;
  @override
  String? get weight;
  @override
  String? get height;
  @override
  String? get medicalConditions;
  @override
  bool get noMedicalConditions;
  @override
  String? get personalNumber;
  @override
  String? get address;
  @override
  String? get avatarUrl;
  @override
  String? get idPhotoUrl;
  @override
  double? get targetWeightKg;
  @override
  @JsonKey(ignore: true)
  _$$UserEntityImplCopyWith<_$UserEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
