import 'package:dio/dio.dart';
import '../../domain/entities/badge_entity.dart';
import '../../domain/entities/gamification_profile.dart';

class GamificationRemoteDataSource {
  final Dio _dio;
  GamificationRemoteDataSource(this._dio);

  Future<GamificationProfile> getProfile() async {
    final res = await _dio.get('/gamification/profile');
    final d   = res.data['data'] as Map<String, dynamic>;

    final badges = ((d['recentBadges'] as List?) ?? [])
        .map((b) => BadgeEntity.fromJson(b as Map<String, dynamic>))
        .toList();

    return GamificationProfile(
      totalPoints:     (d['totalPoints'] as num?)?.toInt() ?? 0,
      level:           (d['level'] as num?)?.toInt() ?? 1,
      levelName:       d['levelName']?.toString() ?? 'Rookie',
      streakDays:      (d['streakDays'] as num?)?.toInt() ?? 0,
      recentBadges:    badges,
      nextLevelPoints: (d['nextLevelPoints'] as num?)?.toInt(),
    );
  }
}
