class TrainingSessionModel {
  final String id;
  final String gymId;
  final String title;
  final String? description;
  final String type; // GROUP_CLASS | ONE_ON_ONE | WORKSHOP
  final DateTime startTime;
  final DateTime endTime;
  final int? maxCapacity;
  final String? location;
  final String? color;
  final String status; // SCHEDULED | CANCELLED | COMPLETED
  final TrainerSummary? trainer;
  final int confirmedCount;
  bool isBooked; // populated client-side from my-bookings

  TrainingSessionModel({
    required this.id,
    required this.gymId,
    required this.title,
    this.description,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.maxCapacity,
    this.location,
    this.color,
    required this.status,
    this.trainer,
    required this.confirmedCount,
    this.isBooked = false,
  });

  factory TrainingSessionModel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return TrainingSessionModel(
      id: json['id']?.toString() ?? '',
      gymId: json['gymId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description'] as String?,
      type: json['type']?.toString() ?? '',
      startTime: DateTime.tryParse(json['startTime']?.toString() ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(json['endTime']?.toString() ?? '') ?? DateTime.now(),
      maxCapacity: (json['maxCapacity'] as num?)?.toInt(),
      location: json['location'] as String?,
      color: json['color'] as String?,
      status: json['status']?.toString() ?? 'SCHEDULED',
      trainer: json['trainer'] != null
          ? TrainerSummary.fromJson(json['trainer'] as Map<String, dynamic>)
          : null,
      confirmedCount: (count?['bookings'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isFull => maxCapacity != null && confirmedCount >= maxCapacity!;
  int get spotsLeft => maxCapacity == null ? 999 : (maxCapacity! - confirmedCount).clamp(0, maxCapacity!);

  String get typeLabel {
    switch (type) {
      case 'GROUP_CLASS': return 'Group Class';
      case 'ONE_ON_ONE': return '1-on-1';
      case 'WORKSHOP': return 'Workshop';
      default: return type;
    }
  }
}

class TrainerSummary {
  final String id;
  final String fullName;
  final String? avatarUrl;

  const TrainerSummary({required this.id, required this.fullName, this.avatarUrl});

  factory TrainerSummary.fromJson(Map<String, dynamic> json) => TrainerSummary(
        id: json['id']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        avatarUrl: json['avatarUrl'] as String?,
      );
}
