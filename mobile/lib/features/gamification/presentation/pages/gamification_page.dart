import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/entities/badge_entity.dart';
import '../../domain/entities/gamification_profile.dart';
import '../providers/gamification_provider.dart';

class GamificationPage extends ConsumerWidget {
  const GamificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(gamificationProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBrand),
        ),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(e.toString(), style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(gamificationProvider.notifier).load(),
              child: const Text('Retry', style: TextStyle(color: AppTheme.primaryBrand)),
            ),
          ]),
        ),
        data: (profile) => _ProfileView(profile: profile),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final GamificationProfile profile;
  const _ProfileView({required this.profile});

  Color _tierColor(String tier) {
    switch (tier) {
      case 'PLATINUM': return const Color(0xFFE0E7FF);
      case 'GOLD':     return const Color(0xFFFBBF24);
      case 'SILVER':   return const Color(0xFF9CA3AF);
      default:         return const Color(0xFFB45309); // BRONZE
    }
  }

  double get _levelProgress {
    if (profile.nextLevelPoints == null || profile.nextLevelPoints == 0) return 1.0;
    // Approximate: points since last threshold / points to next level
    final prevThreshold = _levelThreshold(profile.level - 1);
    final nextThreshold = profile.nextLevelPoints!;
    final current       = profile.totalPoints - prevThreshold;
    final needed        = nextThreshold - prevThreshold;
    if (needed <= 0) return 1.0;
    return (current / needed).clamp(0.0, 1.0);
  }

  int _levelThreshold(int level) {
    if (level <= 0) return 0;
    return level * 1000; // simple linear — matches backend
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Hero header ───────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
          flexibleSpace: FlexibleSpaceBar(
            background: _HeroHeader(profile: profile, levelProgress: _levelProgress),
          ),
          title: const Text('Progress', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),

        // ── Stats row ─────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _StatCard(label: 'Total Points', value: '${profile.totalPoints}', icon: Icons.star_rounded, color: AppTheme.primaryBrand),
                const SizedBox(width: 10),
                _StatCard(label: 'Level', value: profile.levelName, icon: Icons.emoji_events_rounded, color: const Color(0xFFFBBF24)),
                const SizedBox(width: 10),
                _StatCard(label: 'Streak', value: '${profile.streakDays}d 🔥', icon: Icons.local_fire_department_rounded, color: const Color(0xFFEF4444)),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
        ),

        // ── Badges ────────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Badges',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('${profile.recentBadges.length} earned',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              ],
            ),
          ),
        ),

        if (profile.recentBadges.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: Row(
                  children: [
                    Icon(Icons.military_tech_rounded, color: Colors.white.withValues(alpha: 0.2), size: 32),
                    const SizedBox(width: 14),
                    Text('Complete tasks to earn badges!',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final badge = profile.recentBadges[i];
                  return _BadgeTile(badge: badge, tierColor: _tierColor(badge.tier))
                      .animate()
                      .fadeIn(delay: (80 * i).ms)
                      .scale(begin: const Offset(0.8, 0.8));
                },
                childCount: profile.recentBadges.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ── Hero header ────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final GamificationProfile profile;
  final double levelProgress;
  const _HeroHeader({required this.profile, required this.levelProgress});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBrand.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Level badge
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryBrand, AppTheme.primaryBrand.withValues(alpha: 0.6)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${profile.level}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.levelName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('${profile.totalPoints} pts total',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // XP progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: levelProgress,
                  minHeight: 7,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBrand),
                ),
              ),
              const SizedBox(height: 6),
              if (profile.nextLevelPoints != null)
                Text(
                  '${profile.nextLevelPoints! - profile.totalPoints} pts to Level ${profile.level + 1}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Badge tile ─────────────────────────────────────────────────────────────────

class _BadgeTile extends StatelessWidget {
  final BadgeEntity badge;
  final Color tierColor;
  const _BadgeTile({required this.badge, required this.tierColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: tierColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tierColor.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.military_tech_rounded, color: tierColor, size: 24),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(badge.name,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 2),
          Text(badge.tier,
              style: TextStyle(color: tierColor.withValues(alpha: 0.8), fontSize: 9)),
        ],
      ),
    );
  }
}
