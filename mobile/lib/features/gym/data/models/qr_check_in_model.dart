import '../../domain/entities/qr_check_in_entity.dart';

class QrCheckInModel {
  final String checkInId;
  final String gymId;
  final String gymName;
  final DateTime admittedAt;
  final DateTime expiresAt;
  final String? memberName;
  final String? planName;
  final int? daysRemaining;
  final DateTime? membershipEndsAt;
  final bool alreadyCheckedIn;

  const QrCheckInModel({
    required this.checkInId,
    required this.gymId,
    required this.gymName,
    required this.admittedAt,
    required this.expiresAt,
    this.memberName,
    this.planName,
    this.daysRemaining,
    this.membershipEndsAt,
    this.alreadyCheckedIn = false,
  });

  factory QrCheckInModel.fromJson(Map<String, dynamic> json) {
    final endsAt = json['membershipEndsAt'] as String?;
    return QrCheckInModel(
      checkInId: json['checkInId']?.toString() ?? '',
      gymId: json['gymId']?.toString() ?? '',
      gymName: json['gymName']?.toString() ?? '',
      admittedAt: DateTime.tryParse(json['admittedAt']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? '') ?? DateTime.now(),
      memberName: json['memberName'] as String?,
      planName: json['planName'] as String?,
      daysRemaining: json['daysRemaining'] as int?,
      membershipEndsAt: endsAt != null ? DateTime.tryParse(endsAt) : null,
      alreadyCheckedIn: (json['alreadyCheckedIn'] as bool?) ?? false,
    );
  }

  QrCheckInEntity toEntity() => QrCheckInEntity(
        checkInId: checkInId,
        gymId: gymId,
        gymName: gymName,
        admittedAt: admittedAt,
        expiresAt: expiresAt,
        memberName: memberName,
        planName: planName,
        daysRemaining: daysRemaining,
        membershipEndsAt: membershipEndsAt,
        alreadyCheckedIn: alreadyCheckedIn,
      );
}
