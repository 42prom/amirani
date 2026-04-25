import 'package:dio/dio.dart';
import '../models/reward_model.dart';

abstract class GamificationDataSource {
  Future<({int totalPoints, List<RewardModel> rewards})> getRewards();
  Future<RedemptionModel> redeemReward(String rewardId);
  Future<List<RedemptionModel>> getRedemptionHistory({int limit = 20, int offset = 0});
}

class GamificationDataSourceImpl implements GamificationDataSource {
  final Dio _dio;
  GamificationDataSourceImpl(this._dio);

  @override
  Future<({int totalPoints, List<RewardModel> rewards})> getRewards() async {
    final res = await _dio.get('/gamification/rewards');
    final data = res.data['data'] as Map<String, dynamic>;
    return (
      totalPoints: (data['totalPoints'] as num).toInt(),
      rewards: (data['rewards'] as List)
          .map((r) => RewardModel.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<RedemptionModel> redeemReward(String rewardId) async {
    final res = await _dio.post('/gamification/redeem', data: {'rewardId': rewardId});
    return RedemptionModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<RedemptionModel>> getRedemptionHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _dio.get(
      '/gamification/redemption-history',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final data = res.data['data'] as Map<String, dynamic>;
    return (data['items'] as List)
        .map((r) => RedemptionModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
