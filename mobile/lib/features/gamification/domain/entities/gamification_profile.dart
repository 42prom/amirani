import 'badge_entity.dart';

/// Plain Dart class — no Freezed. Stale generated file was deleted.
class GamificationProfile {
  final int totalPoints;
  final int level;
  final String levelName;
  final int streakDays;
  final List<BadgeEntity> recentBadges;
  final int? nextLevelPoints;

  const GamificationProfile({
    required this.totalPoints,
    required this.level,
    required this.levelName,
    required this.streakDays,
    required this.recentBadges,
    this.nextLevelPoints,
  });

  GamificationProfile copyWith({
    int? totalPoints,
    int? level,
    String? levelName,
    int? streakDays,
    List<BadgeEntity>? recentBadges,
    int? nextLevelPoints,
  }) =>
      GamificationProfile(
        totalPoints:     totalPoints    ?? this.totalPoints,
        level:           level          ?? this.level,
        levelName:       levelName      ?? this.levelName,
        streakDays:      streakDays     ?? this.streakDays,
        recentBadges:    recentBadges   ?? this.recentBadges,
        nextLevelPoints: nextLevelPoints ?? this.nextLevelPoints,
      );
}
