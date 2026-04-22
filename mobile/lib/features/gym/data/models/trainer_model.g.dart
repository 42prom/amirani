// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trainer_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TrainerModelImpl _$$TrainerModelImplFromJson(Map<String, dynamic> json) =>
    _$TrainerModelImpl(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      specialization: json['specialization'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
    );

Map<String, dynamic> _$$TrainerModelImplToJson(_$TrainerModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fullName': instance.fullName,
      'specialization': instance.specialization,
      'bio': instance.bio,
      'avatarUrl': instance.avatarUrl,
      'isAvailable': instance.isAvailable,
    };
