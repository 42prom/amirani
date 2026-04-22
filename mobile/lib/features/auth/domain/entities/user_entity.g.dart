// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserEntityImpl _$$UserEntityImplFromJson(Map<String, dynamic> json) =>
    _$UserEntityImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      managedGymId: json['managedGymId'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      fullName: json['fullName'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      gender: json['gender'] as String?,
      dob: json['dob'] as String?,
      weight: json['weight'] as String?,
      height: json['height'] as String?,
      medicalConditions: json['medicalConditions'] as String?,
      noMedicalConditions: json['noMedicalConditions'] as bool? ?? false,
      personalNumber: json['personalNumber'] as String?,
      address: json['address'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      idPhotoUrl: json['idPhotoUrl'] as String?,
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$UserEntityImplToJson(_$UserEntityImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'role': instance.role,
      'managedGymId': instance.managedGymId,
      'phoneNumber': instance.phoneNumber,
      'fullName': instance.fullName,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'gender': instance.gender,
      'dob': instance.dob,
      'weight': instance.weight,
      'height': instance.height,
      'medicalConditions': instance.medicalConditions,
      'noMedicalConditions': instance.noMedicalConditions,
      'personalNumber': instance.personalNumber,
      'address': instance.address,
      'avatarUrl': instance.avatarUrl,
      'idPhotoUrl': instance.idPhotoUrl,
      'targetWeightKg': instance.targetWeightKg,
    };
