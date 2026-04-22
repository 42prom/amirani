import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/dashboard_entity.dart';

part 'dashboard_model.freezed.dart';
part 'dashboard_model.g.dart';

@freezed
class DashboardModel with _$DashboardModel {
  const factory DashboardModel({
    required int activeCaloriesBurned,
    required int activeMinutes,
    required int workoutsCompletedWeek,
    required String activeChallengeName,
    required double activeChallengeProgress,
    @Default([]) List<double> weeklySparks,
  }) = _DashboardModel;

  factory DashboardModel.fromJson(Map<String, dynamic> json) =>
      _$DashboardModelFromJson(json);
}

extension DashboardModelX on DashboardModel {
  DashboardEntity toEntity() {
    return DashboardEntity(
      activeCaloriesBurned: activeCaloriesBurned,
      activeMinutes: activeMinutes,
      workoutsCompletedWeek: workoutsCompletedWeek,
      activeChallengeName: activeChallengeName,
      activeChallengeProgress: activeChallengeProgress,
      weeklySparks: weeklySparks,
    );
  }
}
