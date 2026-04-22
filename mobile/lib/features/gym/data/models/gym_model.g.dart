// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gym_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GymModelImpl _$$GymModelImplFromJson(Map<String, dynamic> json) =>
    _$GymModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      currentOccupancy: (json['currentOccupancy'] as num).toInt(),
      maxCapacity: (json['maxCapacity'] as num).toInt(),
      trainers: (json['trainers'] as List<dynamic>?)
              ?.map((e) => TrainerModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      registrationRequirements: json['registrationRequirements'] == null
          ? null
          : RegistrationRequirementsEntity.fromJson(
              json['registrationRequirements'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$GymModelImplToJson(_$GymModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'address': instance.address,
      'currentOccupancy': instance.currentOccupancy,
      'maxCapacity': instance.maxCapacity,
      'trainers': instance.trainers,
      'registrationRequirements': instance.registrationRequirements,
    };
