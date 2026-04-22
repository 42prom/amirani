// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DashboardModelImpl _$$DashboardModelImplFromJson(Map<String, dynamic> json) =>
    _$DashboardModelImpl(
      activeCaloriesBurned: (json['activeCaloriesBurned'] as num).toInt(),
      activeMinutes: (json['activeMinutes'] as num).toInt(),
      workoutsCompletedWeek: (json['workoutsCompletedWeek'] as num).toInt(),
      activeChallengeName: json['activeChallengeName'] as String,
      activeChallengeProgress:
          (json['activeChallengeProgress'] as num).toDouble(),
      weeklySparks: (json['weeklySparks'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$DashboardModelImplToJson(
        _$DashboardModelImpl instance) =>
    <String, dynamic>{
      'activeCaloriesBurned': instance.activeCaloriesBurned,
      'activeMinutes': instance.activeMinutes,
      'workoutsCompletedWeek': instance.workoutsCompletedWeek,
      'activeChallengeName': instance.activeChallengeName,
      'activeChallengeProgress': instance.activeChallengeProgress,
      'weeklySparks': instance.weeklySparks,
    };
