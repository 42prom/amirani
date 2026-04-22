// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserModel _$UserModelFromJson(Map<String, dynamic> json) {
  return _UserModel.fromJson(json);
}

/// @nodoc
mixin _$UserModel {
  @HiveField(0)
  String get id => throw _privateConstructorUsedError;
  @HiveField(1)
  String get email => throw _privateConstructorUsedError;
  @HiveField(2)
  String get role => throw _privateConstructorUsedError;
  @HiveField(3)
  String? get managedGymId => throw _privateConstructorUsedError;
  @HiveField(4)
  String? get phoneNumber => throw _privateConstructorUsedError;
  @HiveField(5)
  String? get fullName => throw _privateConstructorUsedError;
  @HiveField(6)
  String? get firstName => throw _privateConstructorUsedError;
  @HiveField(7)
  String? get lastName => throw _privateConstructorUsedError;
  @HiveField(8)
  String? get gender => throw _privateConstructorUsedError;
  @HiveField(9)
  String? get dob => throw _privateConstructorUsedError;
  @HiveField(10)
  String? get weight => throw _privateConstructorUsedError;
  @HiveField(11)
  String? get height => throw _privateConstructorUsedError;
  @HiveField(12)
  String? get medicalConditions => throw _privateConstructorUsedError;
  @HiveField(13)
  bool get noMedicalConditions => throw _privateConstructorUsedError;
  @HiveField(14)
  String? get personalNumber => throw _privateConstructorUsedError;
  @HiveField(15)
  String? get address => throw _privateConstructorUsedError;
  @HiveField(16)
  String? get avatarUrl => throw _privateConstructorUsedError;
  @HiveField(17)
  String? get idPhotoUrl => throw _privateConstructorUsedError;
  @HiveField(18)
  double? get targetWeightKg => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserModelCopyWith<UserModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserModelCopyWith<$Res> {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) then) =
      _$UserModelCopyWithImpl<$Res, UserModel>;
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) String email,
      @HiveField(2) String role,
      @HiveField(3) String? managedGymId,
      @HiveField(4) String? phoneNumber,
      @HiveField(5) String? fullName,
      @HiveField(6) String? firstName,
      @HiveField(7) String? lastName,
      @HiveField(8) String? gender,
      @HiveField(9) String? dob,
      @HiveField(10) String? weight,
      @HiveField(11) String? height,
      @HiveField(12) String? medicalConditions,
      @HiveField(13) bool noMedicalConditions,
      @HiveField(14) String? personalNumber,
      @HiveField(15) String? address,
      @HiveField(16) String? avatarUrl,
      @HiveField(17) String? idPhotoUrl,
      @HiveField(18) double? targetWeightKg});
}

/// @nodoc
class _$UserModelCopyWithImpl<$Res, $Val extends UserModel>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._value, this._then);

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
abstract class _$$UserModelImplCopyWith<$Res>
    implements $UserModelCopyWith<$Res> {
  factory _$$UserModelImplCopyWith(
          _$UserModelImpl value, $Res Function(_$UserModelImpl) then) =
      __$$UserModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) String email,
      @HiveField(2) String role,
      @HiveField(3) String? managedGymId,
      @HiveField(4) String? phoneNumber,
      @HiveField(5) String? fullName,
      @HiveField(6) String? firstName,
      @HiveField(7) String? lastName,
      @HiveField(8) String? gender,
      @HiveField(9) String? dob,
      @HiveField(10) String? weight,
      @HiveField(11) String? height,
      @HiveField(12) String? medicalConditions,
      @HiveField(13) bool noMedicalConditions,
      @HiveField(14) String? personalNumber,
      @HiveField(15) String? address,
      @HiveField(16) String? avatarUrl,
      @HiveField(17) String? idPhotoUrl,
      @HiveField(18) double? targetWeightKg});
}

/// @nodoc
class __$$UserModelImplCopyWithImpl<$Res>
    extends _$UserModelCopyWithImpl<$Res, _$UserModelImpl>
    implements _$$UserModelImplCopyWith<$Res> {
  __$$UserModelImplCopyWithImpl(
      _$UserModelImpl _value, $Res Function(_$UserModelImpl) _then)
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
    return _then(_$UserModelImpl(
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
class _$UserModelImpl implements _UserModel {
  const _$UserModelImpl(
      {@HiveField(0) required this.id,
      @HiveField(1) required this.email,
      @HiveField(2) required this.role,
      @HiveField(3) this.managedGymId,
      @HiveField(4) this.phoneNumber,
      @HiveField(5) this.fullName,
      @HiveField(6) this.firstName,
      @HiveField(7) this.lastName,
      @HiveField(8) this.gender,
      @HiveField(9) this.dob,
      @HiveField(10) this.weight,
      @HiveField(11) this.height,
      @HiveField(12) this.medicalConditions,
      @HiveField(13) this.noMedicalConditions = false,
      @HiveField(14) this.personalNumber,
      @HiveField(15) this.address,
      @HiveField(16) this.avatarUrl,
      @HiveField(17) this.idPhotoUrl,
      @HiveField(18) this.targetWeightKg});

  factory _$UserModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserModelImplFromJson(json);

  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String email;
  @override
  @HiveField(2)
  final String role;
  @override
  @HiveField(3)
  final String? managedGymId;
  @override
  @HiveField(4)
  final String? phoneNumber;
  @override
  @HiveField(5)
  final String? fullName;
  @override
  @HiveField(6)
  final String? firstName;
  @override
  @HiveField(7)
  final String? lastName;
  @override
  @HiveField(8)
  final String? gender;
  @override
  @HiveField(9)
  final String? dob;
  @override
  @HiveField(10)
  final String? weight;
  @override
  @HiveField(11)
  final String? height;
  @override
  @HiveField(12)
  final String? medicalConditions;
  @override
  @JsonKey()
  @HiveField(13)
  final bool noMedicalConditions;
  @override
  @HiveField(14)
  final String? personalNumber;
  @override
  @HiveField(15)
  final String? address;
  @override
  @HiveField(16)
  final String? avatarUrl;
  @override
  @HiveField(17)
  final String? idPhotoUrl;
  @override
  @HiveField(18)
  final double? targetWeightKg;

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, role: $role, managedGymId: $managedGymId, phoneNumber: $phoneNumber, fullName: $fullName, firstName: $firstName, lastName: $lastName, gender: $gender, dob: $dob, weight: $weight, height: $height, medicalConditions: $medicalConditions, noMedicalConditions: $noMedicalConditions, personalNumber: $personalNumber, address: $address, avatarUrl: $avatarUrl, idPhotoUrl: $idPhotoUrl, targetWeightKg: $targetWeightKg)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserModelImpl &&
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
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      __$$UserModelImplCopyWithImpl<_$UserModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserModelImplToJson(
      this,
    );
  }
}

abstract class _UserModel implements UserModel {
  const factory _UserModel(
      {@HiveField(0) required final String id,
      @HiveField(1) required final String email,
      @HiveField(2) required final String role,
      @HiveField(3) final String? managedGymId,
      @HiveField(4) final String? phoneNumber,
      @HiveField(5) final String? fullName,
      @HiveField(6) final String? firstName,
      @HiveField(7) final String? lastName,
      @HiveField(8) final String? gender,
      @HiveField(9) final String? dob,
      @HiveField(10) final String? weight,
      @HiveField(11) final String? height,
      @HiveField(12) final String? medicalConditions,
      @HiveField(13) final bool noMedicalConditions,
      @HiveField(14) final String? personalNumber,
      @HiveField(15) final String? address,
      @HiveField(16) final String? avatarUrl,
      @HiveField(17) final String? idPhotoUrl,
      @HiveField(18) final double? targetWeightKg}) = _$UserModelImpl;

  factory _UserModel.fromJson(Map<String, dynamic> json) =
      _$UserModelImpl.fromJson;

  @override
  @HiveField(0)
  String get id;
  @override
  @HiveField(1)
  String get email;
  @override
  @HiveField(2)
  String get role;
  @override
  @HiveField(3)
  String? get managedGymId;
  @override
  @HiveField(4)
  String? get phoneNumber;
  @override
  @HiveField(5)
  String? get fullName;
  @override
  @HiveField(6)
  String? get firstName;
  @override
  @HiveField(7)
  String? get lastName;
  @override
  @HiveField(8)
  String? get gender;
  @override
  @HiveField(9)
  String? get dob;
  @override
  @HiveField(10)
  String? get weight;
  @override
  @HiveField(11)
  String? get height;
  @override
  @HiveField(12)
  String? get medicalConditions;
  @override
  @HiveField(13)
  bool get noMedicalConditions;
  @override
  @HiveField(14)
  String? get personalNumber;
  @override
  @HiveField(15)
  String? get address;
  @override
  @HiveField(16)
  String? get avatarUrl;
  @override
  @HiveField(17)
  String? get idPhotoUrl;
  @override
  @HiveField(18)
  double? get targetWeightKg;
  @override
  @JsonKey(ignore: true)
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
