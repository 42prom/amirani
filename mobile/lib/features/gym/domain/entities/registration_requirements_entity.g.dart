// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registration_requirements_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RegistrationRequirementsEntityImpl
    _$$RegistrationRequirementsEntityImplFromJson(Map<String, dynamic> json) =>
        _$RegistrationRequirementsEntityImpl(
          fullName: json['fullName'] as bool? ?? true,
          dateOfBirth: json['dateOfBirth'] as bool? ?? false,
          personalNumber: json['personalNumber'] as bool? ?? false,
          phoneNumber: json['phoneNumber'] as bool? ?? false,
          address: json['address'] as bool? ?? false,
          selfiePhoto: json['selfiePhoto'] as bool? ?? false,
          idPhoto: json['idPhoto'] as bool? ?? false,
          healthInfo: json['healthInfo'] as bool? ?? false,
        );

Map<String, dynamic> _$$RegistrationRequirementsEntityImplToJson(
        _$RegistrationRequirementsEntityImpl instance) =>
    <String, dynamic>{
      'fullName': instance.fullName,
      'dateOfBirth': instance.dateOfBirth,
      'personalNumber': instance.personalNumber,
      'phoneNumber': instance.phoneNumber,
      'address': instance.address,
      'selfiePhoto': instance.selfiePhoto,
      'idPhoto': instance.idPhoto,
      'healthInfo': instance.healthInfo,
    };
