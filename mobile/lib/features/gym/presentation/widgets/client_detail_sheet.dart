import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import 'package:amirani_app/core/widgets/user_avatar.dart';
import '../providers/trainer_platform_provider.dart';

class ClientDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> memberData;

  const ClientDetailSheet({super.key, required this.memberData});

  static void show(BuildContext context, Map<String, dynamic> memberData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClientDetailSheet(memberData: memberData),
    );
  }

  @override
  ConsumerState<ClientDetailSheet> createState() => _ClientDetailSheetState();
}

class _ClientDetailSheetState extends ConsumerState<ClientDetailSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final memberId = widget.memberData['user']?['id']?.toString() ?? '';
      if (memberId.isNotEmpty) {
        ref.read(trainerPlatformProvider.notifier).fetchMemberStats(memberId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final memberId = widget.memberData['user']?['id']?.toString() ?? '';
    final platformState = ref.watch(trainerPlatformProvider);
    final statsData = platformState.memberStatsCache[memberId];
    
    final user = widget.memberData['user'] as Map<String, dynamic>? ?? {};
    final String fullName = user['fullName']?.toString() ?? 'Client';
    final String? avatarUrl = user['avatarUrl'] as String?;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTokens.colorBgPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              height: 4, width: 40,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        UserAvatar(imagePath: avatarUrl, displayName: fullName, size: 80),
                        const SizedBox(height: 16),
                        Text(fullName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(user['email']?.toString() ?? '', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                        const SizedBox(height: 32),
                        
                        if (statsData == null)
                          const Center(child: CircularProgressIndicator(color: AppTokens.colorBrand))
                        else
                          _buildStatsGrid(statsData['stats'] as Map<String, dynamic>? ?? {}),
                        
                        const SizedBox(height: 32),
                        const Align(alignment: Alignment.centerLeft, child: Text('Recent Attendance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 16),
                        
                        if (statsData != null)
                          _buildAttendanceList(statsData['recentAttendance'] as List<dynamic>? ?? [])
                        else
                          const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildStatCard('Total Visits', stats['totalVisits']?.toString() ?? '0', Icons.calendar_today),
        _buildStatCard('Attendance', '${stats['attendanceRate'] ?? 0}%', Icons.trending_up),
        _buildStatCard('Avg Session', '${stats['avgSessionMinutes'] ?? 0}m', Icons.timer),
        _buildStatCard('BMI', stats['bmi']?.toString() ?? 'N/A', Icons.fitness_center),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [Icon(icon, color: AppTokens.colorBrand, size: 16), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))]),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAttendanceList(List<dynamic> attendance) {
    if (attendance.isEmpty) return const Text('No recent visits recorded.', style: TextStyle(color: Colors.white38));
    
    return Column(
      children: attendance.map((a) {
        final date = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.now();
        final duration = a['duration']?.toString() ?? '0';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTokens.colorBgSurface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 20),
              const SizedBox(width: 16),
              Expanded(child: Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
              Text('${duration}m', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: AppTokens.colorBgPrimary,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message Client'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTokens.colorBgSurface, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {}, // Future: Manage Plan
              icon: const Icon(Icons.edit_note),
              label: const Text('Manage Plan'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTokens.colorBrand, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
