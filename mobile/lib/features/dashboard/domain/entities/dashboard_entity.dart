import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_entity.freezed.dart';

@freezed
class DashboardEntity with _$DashboardEntity {
  const factory DashboardEntity({
    required int activeCaloriesBurned,
    required int activeMinutes,
    required int workoutsCompletedWeek,
    required String activeChallengeName,
    required double activeChallengeProgress,
    required List<double> weeklySparks, // 7-day sparkline graph values
  }) = _DashboardEntity;
}
