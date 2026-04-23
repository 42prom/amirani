import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/theme/app_theme.dart';
import 'package:amirani_app/core/widgets/app_section_header.dart';
import 'package:amirani_app/core/widgets/user_avatar.dart';
import '../providers/trainer_platform_provider.dart';
import 'client_detail_sheet.dart';

class TrainerDashboard extends ConsumerStatefulWidget {
  const TrainerDashboard({super.key});

  @override
  ConsumerState<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends ConsumerState<TrainerDashboard> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(trainerPlatformProvider.notifier).loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final platformState = ref.watch(trainerPlatformProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(trainerPlatformProvider.notifier).refresh(),
      backgroundColor: AppTheme.surfaceDark,
      color: AppTheme.primaryBrand,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickStats(platformState.dashboardStats),
                  const SizedBox(height: 32),
                  const AppSectionHeader(title: 'My Clients'),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 24),
                  if (platformState.isLoading)
                    const Center(child: CircularProgressIndicator(color: AppTheme.primaryBrand))
                  else if (platformState.error != null)
                    _buildErrorState(platformState.error!)
                  else
                    _buildClientList(platformState.members),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(Map<String, dynamic>? stats) {
    return Row(
      children: [
        _buildStatTile('Check-ins', stats?['todayCheckIns']?.toString() ?? '0', Icons.login, Colors.green),
        const SizedBox(width: 16),
        _buildStatTile('Total Clients', stats?['totalMembers']?.toString() ?? '0', Icons.people, Colors.blue),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search clients...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildClientList(List<dynamic> members) {
    final filtered = members.where((m) {
      final name = m['user']?['fullName']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text(_searchQuery.isEmpty ? 'No clients assigned yet.' : 'No clients found matching your search.', style: const TextStyle(color: Colors.white38))),
      );
    }

    return Column(
      children: filtered.map((m) {
        final user = m['user'] as Map<String, dynamic>? ?? {};
        final String fullName = user['fullName']?.toString() ?? 'Client';
        final String? avatarUrl = user['avatarUrl'] as String?;
        final String status = m['status']?.toString() ?? 'INACTIVE';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => ClientDetailSheet.show(context, m),
            contentPadding: const EdgeInsets.all(12),
            tileColor: AppTheme.surfaceDark.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            leading: UserAvatar(imagePath: avatarUrl, displayName: fullName, size: 48),
            title: Text(fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(m['plan']?['name']?.toString() ?? 'No Active Plan', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (status == 'ACTIVE' ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(status, style: TextStyle(color: status == 'ACTIVE' ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          TextButton(onPressed: () => ref.read(trainerPlatformProvider.notifier).refresh(), child: const Text('Retry', style: TextStyle(color: AppTheme.primaryBrand))),
        ],
      ),
    );
  }
}
