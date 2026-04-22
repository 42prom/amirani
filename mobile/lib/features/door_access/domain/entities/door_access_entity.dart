/// Result of a door access / QR check-in attempt.
class DoorAccessResult {
  final bool success;
  final String memberName;
  final String planName;
  final int daysRemaining;
  final String membershipEndsAt;
  final String? message;

  const DoorAccessResult({
    required this.success,
    required this.memberName,
    required this.planName,
    required this.daysRemaining,
    required this.membershipEndsAt,
    this.message,
  });

  factory DoorAccessResult.fromJson(Map<String, dynamic> j) => DoorAccessResult(
        success:           j['success'] as bool? ?? false,
        memberName:        j['memberName']?.toString() ?? '',
        planName:          j['planName']?.toString() ?? '',
        daysRemaining:     (j['daysRemaining'] as num?)?.toInt() ?? 0,
        membershipEndsAt:  j['membershipEndsAt']?.toString() ?? '',
        message:           j['message'] as String?,
      );
}
