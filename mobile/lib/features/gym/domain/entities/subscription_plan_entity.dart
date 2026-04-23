class SubscriptionPlanEntity {
  final String id;
  final String name;
  final String? description;
  final List<String> features;
  final double price;
  final String durationUnit; // "days" | "months" | "years"
  final int durationValue;

  const SubscriptionPlanEntity({
    required this.id,
    required this.name,
    this.description,
    required this.features,
    required this.price,
    required this.durationUnit,
    required this.durationValue,
  });

  factory SubscriptionPlanEntity.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanEntity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      features: (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      durationUnit: json['durationUnit'] as String? ?? 'days',
      durationValue: (json['durationValue'] as num?)?.toInt() ?? 30,
    );
  }

  String get formattedDuration {
    if (durationValue == 1) {
      return '1 ${durationUnit.substring(0, durationUnit.length - 1)}';
    }
    return '$durationValue $durationUnit';
  }
}
