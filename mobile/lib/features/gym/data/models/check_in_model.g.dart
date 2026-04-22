// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_in_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CheckInModelImpl _$$CheckInModelImplFromJson(Map<String, dynamic> json) =>
    _$CheckInModelImpl(
      id: json['id'] as String,
      gymId: json['gymId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSuccess: json['isSuccess'] as bool,
      message: json['message'] as String,
    );

Map<String, dynamic> _$$CheckInModelImplToJson(_$CheckInModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'gymId': instance.gymId,
      'timestamp': instance.timestamp.toIso8601String(),
      'isSuccess': instance.isSuccess,
      'message': instance.message,
    };
