class BranchInfo {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? phone;
  final int maxCapacity;
  final String? openTime;
  final String? closeTime;

  const BranchInfo({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.phone,
    required this.maxCapacity,
    this.openTime,
    this.closeTime,
  });

  factory BranchInfo.fromJson(Map<String, dynamic> json) => BranchInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        city: json['city'] as String?,
        phone: json['phone'] as String?,
        maxCapacity: (json['maxCapacity'] as num?)?.toInt() ?? 50,
        openTime: json['openTime'] as String?,
        closeTime: json['closeTime'] as String?,
      );

  String get locationLabel {
    final parts = [address, city].where((s) => s != null && s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(', ') : '';
  }

  String get hoursLabel {
    if (openTime != null && closeTime != null) return '$openTime – $closeTime';
    return '';
  }
}
