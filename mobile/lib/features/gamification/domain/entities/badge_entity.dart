/// Plain Dart class — no Freezed. Stale generated files were deleted.
class BadgeEntity {
  final String id;
  final String name;
  final String description;
  final String? iconUrl;
  final String tier; // BRONZE | SILVER | GOLD | PLATINUM
  final DateTime earnedAt;

  const BadgeEntity({
    required this.id,
    required this.name,
    required this.description,
    this.iconUrl,
    required this.tier,
    required this.earnedAt,
  });

  factory BadgeEntity.fromJson(Map<String, dynamic> j) => BadgeEntity(
        id:          j['badge']?['id']?.toString() ?? j['id']?.toString() ?? '',
        name:        j['badge']?['name']?.toString() ?? j['name']?.toString() ?? '',
        description: j['badge']?['description']?.toString() ?? j['description']?.toString() ?? '',
        iconUrl:     j['badge']?['iconUrl'] as String? ?? j['iconUrl'] as String?,
        tier:        j['badge']?['tier']?.toString() ?? j['tier']?.toString() ?? 'BRONZE',
        earnedAt:    DateTime.tryParse(
                       (j['earnedAt'] ?? j['createdAt'])?.toString() ?? '',
                     ) ??
                     DateTime.now(),
      );
}
