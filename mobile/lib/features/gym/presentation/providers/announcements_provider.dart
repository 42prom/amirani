import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/models/announcement_model.dart';

/// Fetches the last 5 announcements for a gym, pinned first.
/// FutureProvider.family keyed by gymId — auto-caches and deduplicates.
final announcementsProvider =
    FutureProvider.family<List<AnnouncementModel>, String>((ref, gymId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/announcements/gyms/$gymId');
  final raw = response.data['data'] as List? ?? [];
  return raw
      .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
      .take(5)
      .toList();
});
