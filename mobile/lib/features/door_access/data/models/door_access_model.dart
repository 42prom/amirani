/// QR check-in log entry.
class DoorAccessModel {
  final String checkInId;
  final String gymId;
  final String gymName;
  final String memberName;
  final String planName;
  final int daysRemaining;
  final String membershipEndsAt;
  final String checkInTime;
  final bool success;

  const DoorAccessModel({
    required this.checkInId,
    required this.gymId,
    required this.gymName,
    required this.memberName,
    required this.planName,
    required this.daysRemaining,
    required this.membershipEndsAt,
    required this.checkInTime,
    required this.success,
  });

  factory DoorAccessModel.fromJson(Map<String, dynamic> j) => DoorAccessModel(
        checkInId:        j['id']?.toString() ?? '',
        gymId:            j['gymId']?.toString() ?? '',
        gymName:          j['gym']?['name']?.toString() ?? '',
        memberName:       j['memberName']?.toString() ?? '',
        planName:         j['planName']?.toString() ?? '',
        daysRemaining:    (j['daysRemaining'] as num?)?.toInt() ?? 0,
        membershipEndsAt: j['membershipEndsAt']?.toString() ?? '',
        checkInTime:      j['checkInTime']?.toString() ?? j['createdAt']?.toString() ?? '',
        success:          j['success'] as bool? ?? true,
      );
}
