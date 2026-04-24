class RoomCreator {
  final String id;
  final String fullName;
  final String? avatarUrl;

  const RoomCreator({required this.id, required this.fullName, this.avatarUrl});

  factory RoomCreator.fromJson(Map<String, dynamic> j) => RoomCreator(
        id: j['id']?.toString() ?? '',
        fullName: j['fullName']?.toString() ?? '',
        avatarUrl: j['avatarUrl'] as String?,
      );
}

class RoomModel {
  final String id;
  final String gymId;
  final String creatorId;
  final String name;
  final String? description;
  final String metric; // CHECKINS | SESSIONS | STREAK
  final String period; // WEEKLY | MONTHLY | ONGOING | CUSTOM
  final DateTime startDate;
  final DateTime? endDate;
  final bool isPublic;
  final String inviteCode;
  final int maxMembers;
  final bool isActive;
  final DateTime createdAt;
  final RoomCreator creator;
  final int memberCount;

  const RoomModel({
    required this.id,
    required this.gymId,
    required this.creatorId,
    required this.name,
    this.description,
    required this.metric,
    required this.period,
    required this.startDate,
    this.endDate,
    required this.isPublic,
    required this.inviteCode,
    required this.maxMembers,
    required this.isActive,
    required this.createdAt,
    required this.creator,
    required this.memberCount,
  });

  factory RoomModel.fromJson(Map<String, dynamic> j) {
    final count = j['_count'] as Map<String, dynamic>?;
    return RoomModel(
      id: j['id']?.toString() ?? '',
      gymId: j['gymId']?.toString() ?? '',
      creatorId: j['creatorId']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      description: j['description'] as String?,
      metric: j['metric']?.toString() ?? 'CHECKINS',
      period: j['period']?.toString() ?? 'ONGOING',
      startDate: DateTime.tryParse(j['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: j['endDate'] != null ? DateTime.tryParse(j['endDate'].toString()) : null,
      isPublic: j['isPublic'] as bool? ?? false,
      inviteCode: j['inviteCode']?.toString() ?? '',
      maxMembers: (j['maxMembers'] as num?)?.toInt() ?? 0,
      isActive: j['isActive'] as bool? ?? false,
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      creator: RoomCreator.fromJson(j['creator'] as Map<String, dynamic>? ?? {}),
      memberCount: (count?['members'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isExpired => endDate != null && endDate!.isBefore(DateTime.now());

  String get metricLabel {
    switch (metric) {
      case 'SESSIONS':  return 'Classes Attended';
      case 'STREAK':    return 'Day Streak';
      case 'COMPOSITE': return 'All-Around Score';
      default:          return 'Check-ins';
    }
  }

  String get periodLabel {
    switch (period) {
      case 'WEEKLY':  return 'Weekly';
      case 'MONTHLY': return 'Monthly';
      case 'CUSTOM':  return 'Custom';
      default:        return 'Ongoing';
    }
  }
}

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final int score;
  final bool isMe;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.score,
    required this.isMe,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        userId: j['userId']?.toString() ?? '',
        fullName: j['fullName']?.toString() ?? '',
        avatarUrl: j['avatarUrl'] as String?,
        score: (j['score'] as num?)?.toInt() ?? 0,
        isMe: j['isMe'] as bool? ?? false,
      );
}

class RoomDetail {
  final RoomModel room;
  final List<LeaderboardEntry> leaderboard;
  final bool isMember;
  final bool isCreator;
  final LeaderboardEntry? myEntry;

  const RoomDetail({
    required this.room,
    required this.leaderboard,
    required this.isMember,
    required this.isCreator,
    this.myEntry,
  });

  factory RoomDetail.fromJson(Map<String, dynamic> j) => RoomDetail(
        room: RoomModel.fromJson(j['room'] as Map<String, dynamic>),
        leaderboard: ((j['leaderboard'] as List?) ?? [])
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        isMember: j['isMember'] as bool? ?? false,
        isCreator: j['isCreator'] as bool? ?? false,
        myEntry: j['myEntry'] != null
            ? LeaderboardEntry.fromJson(j['myEntry'] as Map<String, dynamic>)
            : null,
      );
}

class MyRoomsData {
  final List<RoomModel> myRooms;
  final List<RoomModel> gymRooms;
  final List<RoomModel> availableRooms;
  final String? gymId;

  const MyRoomsData({
    required this.myRooms,
    required this.gymRooms,
    required this.availableRooms,
    this.gymId,
  });

  factory MyRoomsData.fromJson(Map<String, dynamic> j) => MyRoomsData(
        myRooms: ((j['myRooms'] as List?) ?? [])
            .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        gymRooms: ((j['gymRooms'] as List?) ?? [])
            .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        availableRooms: ((j['availableRooms'] as List?) ?? [])
            .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        gymId: j['gymId'] as String?,
      );
}

class ChallengeProgress {
  final int currentValue;
  final bool completed;
  final DateTime? completedAt;

  const ChallengeProgress({
    required this.currentValue,
    required this.completed,
    this.completedAt,
  });

  factory ChallengeProgress.fromJson(Map<String, dynamic> j) => ChallengeProgress(
        currentValue: (j['currentValue'] as num?)?.toInt() ?? 0,
        completed: j['completed'] as bool? ?? false,
        completedAt: j['completedAt'] != null ? DateTime.tryParse(j['completedAt'].toString()) : null,
      );
}

class RoomChallenge {
  final String id;
  final String roomId;
  final String title;
  final String? description;
  final int targetValue;
  final String unit;
  final int pointsReward;
  final bool isActive;
  final DateTime? endDate;
  final DateTime createdAt;
  final ChallengeProgress myProgress;

  const RoomChallenge({
    required this.id,
    required this.roomId,
    required this.title,
    this.description,
    required this.targetValue,
    required this.unit,
    required this.pointsReward,
    required this.isActive,
    this.endDate,
    required this.createdAt,
    required this.myProgress,
  });

  factory RoomChallenge.fromJson(Map<String, dynamic> j) => RoomChallenge(
        id: j['id']?.toString() ?? '',
        roomId: j['roomId']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        description: j['description'] as String?,
        targetValue: (j['targetValue'] as num?)?.toInt() ?? 1,
        unit: j['unit']?.toString() ?? '',
        pointsReward: (j['pointsReward'] as num?)?.toInt() ?? 0,
        isActive: j['isActive'] as bool? ?? true,
        endDate: j['endDate'] != null ? DateTime.tryParse(j['endDate'].toString()) : null,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
        myProgress: j['myProgress'] != null
            ? ChallengeProgress.fromJson(j['myProgress'] as Map<String, dynamic>)
            : const ChallengeProgress(currentValue: 0, completed: false),
      );

  double get progressFraction =>
      targetValue > 0 ? (myProgress.currentValue / targetValue).clamp(0.0, 1.0) : 0.0;
}

class RoomMessage {
  final String id;
  final String roomId;
  final String userId;
  final String body;
  final String? imageUrl;
  final DateTime createdAt;
  final RoomCreator user;

  const RoomMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.body,
    this.imageUrl,
    required this.createdAt,
    required this.user,
  });

  factory RoomMessage.fromJson(Map<String, dynamic> j) => RoomMessage(
        id: j['id']?.toString() ?? '',
        roomId: j['roomId']?.toString() ?? '',
        userId: j['userId']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        imageUrl: j['imageUrl'] as String?,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
        user: RoomCreator.fromJson(j['user'] as Map<String, dynamic>? ?? {}),
      );
}
