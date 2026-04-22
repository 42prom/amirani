class QrCheckInEntity {
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

  const QrCheckInEntity({
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

  bool get isActive => DateTime.now().isBefore(expiresAt);

  String get formattedAdmittedAt {
    final h = admittedAt.hour.toString().padLeft(2, '0');
    final m = admittedAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get formattedExpiresAt {
    final h = expiresAt.hour.toString().padLeft(2, '0');
    final m = expiresAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
