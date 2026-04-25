import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class ReferralInfo {
  final String code;
  final String shareLink;
  final int usedCount;
  final int pointsEarned;

  const ReferralInfo({
    required this.code,
    required this.shareLink,
    required this.usedCount,
    required this.pointsEarned,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) => ReferralInfo(
        code: json['code'] as String,
        shareLink: json['shareLink'] as String,
        usedCount: (json['usedCount'] as num).toInt(),
        pointsEarned: (json['pointsEarned'] as num).toInt(),
      );
}

final referralProvider = FutureProvider<ReferralInfo>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/referrals/my-code');
  return ReferralInfo.fromJson(res.data['data'] as Map<String, dynamic>);
});
