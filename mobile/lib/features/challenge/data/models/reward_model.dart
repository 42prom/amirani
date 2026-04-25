class RewardModel {
  final String id;
  final String name;
  final String? description;
  final int pointsCost;
  final int? stock;
  final String? imageUrl;
  final String? gymId;
  final bool isActive;
  final DateTime? expiresAt;

  const RewardModel({
    required this.id,
    required this.name,
    this.description,
    required this.pointsCost,
    this.stock,
    this.imageUrl,
    this.gymId,
    required this.isActive,
    this.expiresAt,
  });

  factory RewardModel.fromJson(Map<String, dynamic> json) => RewardModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        pointsCost: (json['pointsCost'] as num).toInt(),
        stock: (json['stock'] as num?)?.toInt(),
        imageUrl: json['imageUrl'] as String?,
        gymId: json['gymId'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        expiresAt: json['expiresAt'] != null
            ? DateTime.tryParse(json['expiresAt'] as String)
            : null,
      );

  RewardModel copyWith({int? stock}) => RewardModel(
        id: id,
        name: name,
        description: description,
        pointsCost: pointsCost,
        stock: stock ?? this.stock,
        imageUrl: imageUrl,
        gymId: gymId,
        isActive: isActive,
        expiresAt: expiresAt,
      );
}

class RedemptionModel {
  final String id;
  final String rewardId;
  final int pointsSpent;
  final String status;
  final DateTime redeemedAt;
  final String? rewardName;
  final String? rewardImageUrl;

  const RedemptionModel({
    required this.id,
    required this.rewardId,
    required this.pointsSpent,
    required this.status,
    required this.redeemedAt,
    this.rewardName,
    this.rewardImageUrl,
  });

  factory RedemptionModel.fromJson(Map<String, dynamic> json) {
    final reward = json['reward'] as Map<String, dynamic>?;
    return RedemptionModel(
      id: json['id'] as String,
      rewardId: json['rewardId'] as String,
      pointsSpent: (json['pointsSpent'] as num).toInt(),
      status: json['status'] as String? ?? 'PENDING',
      redeemedAt:
          DateTime.tryParse(json['redeemedAt']?.toString() ?? '') ?? DateTime.now(),
      rewardName: reward?['name'] as String?,
      rewardImageUrl: reward?['imageUrl'] as String?,
    );
  }
}
