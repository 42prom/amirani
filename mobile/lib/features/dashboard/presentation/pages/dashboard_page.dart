import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/dashboard_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../profile/presentation/widgets/profile_settings_modal.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../gym/presentation/providers/gym_access_provider.dart';
import '../../../../core/providers/session_progress_provider.dart';
import '../../../../core/providers/day_selector_providers.dart';
import '../../../../core/widgets/premium_state_card.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../providers/recovery_provider.dart';
import '../widgets/recovery_check_in_sheet.dart';
import '../../../challenge/presentation/widgets/score_history_chart.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(dashboardNotifierProvider.notifier).fetchDashboardMetrics();
      ref.read(recoveryProvider.notifier).fetchToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardNotifierProvider);
    final profileSync = ref.watch(profileSyncProvider);
    final authState = ref.watch(authNotifierProvider);
    final sessionProgress = ref.watch(sessionProgressProvider);

    final String? role =
        authState is AuthAuthenticated ? authState.user.role : null;
    final String? managedGymId =
        authState is AuthAuthenticated ? authState.user.managedGymId : null;
    final bool isBranchManager = role == 'branch_manager';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(profileSync),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryBrand,
                onRefresh: () async {
                  ref.read(dashboardNotifierProvider.notifier).fetchDashboardMetrics();
                  ref.read(recoveryProvider.notifier).fetchToday();
                },
                child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    if (isBranchManager && managedGymId != null) ...[
                      _buildBranchQrCard(managedGymId),
                      const SizedBox(height: 24),
                    ],
                    _buildBody(state, sessionProgress, context),
                  ],
                ),
              ),
              ), // closes RefreshIndicator
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ProfileSyncState profileSync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => ProfileSettingsModal.show(context),
                child: UserAvatar(
                  imagePath: profileSync.profileImagePath,
                  displayName: profileSync.fullName,
                  size: 40,
                  badge: Container(
                    height: 12,
                    width: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryBrand,
                      border: Border.all(color: AppTheme.backgroundDark, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hello,',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500)),
                  Text(
                      profileSync.firstName.isNotEmpty
                          ? profileSync.firstName
                          : (profileSync.fullName.isNotEmpty
                              ? profileSync.fullName.split(' ')[0]
                              : 'Your Name'),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
            ],
          ),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surfaceDark.withValues(alpha: 0.5),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.05))),
            child:
                const Icon(Icons.light_mode, color: Colors.white54, size: 20),
          )
        ],
      ),
    );
  }

  Widget _buildBody(DashboardState state, SessionProgressState sessionProgress, BuildContext context) {
    if (state is DashboardLoading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.only(top: 100),
        child: CircularProgressIndicator(color: AppTheme.primaryBrand),
      ));
    }

    if (state is DashboardError) {
      // Graceful offline degradation logic for dashboard
      return _buildOfflineFallback(context);
    }

    if (state is DashboardLoaded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDaySelector(),
          const SizedBox(height: 24),
          _buildAggregatedProgress(sessionProgress),
          const SizedBox(height: 24),
          const ScoreHistoryChart(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Active Tasks",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text("${sessionProgress.totalTasks - sessionProgress.completedTasks} Remaining",
                  style: TextStyle(
                      color: AppTheme.primaryBrand.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildHydrationCard(sessionProgress.hydration),
          ...sessionProgress.meals.map((meal) => _buildMealTaskCard(meal)),
          if (sessionProgress.totalExercises > 0)
            _buildWorkoutSummaryCard(sessionProgress),
          _buildRecoveryCard(),
          const SizedBox(height: 80), // Footer padding
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ─── Branch Manager QR Card ────────────────────────────────────────────────

  Widget _buildBranchQrCard(String gymId) {
    final tokenAsync = ref.watch(gymQrTokenProvider(gymId));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: AppTheme.primaryBrand.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBrand.withValues(alpha: 0.06),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryBrand.withValues(alpha: 0.15),
                  border: Border.all(
                      color: AppTheme.primaryBrand.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.qr_code_2,
                    color: AppTheme.primaryBrand, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Branch QR Code',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text('Members scan this to enter',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // QR or loading/error state
          tokenAsync.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryBrand, strokeWidth: 2),
              ),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: PremiumStateCard(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Failed to load QR code',
                subtitle: 'Check your connection and try again.',
                onAction: () => ref.invalidate(gymQrTokenProvider(gymId)),
                actionLabel: 'Retry',
              ),
            ),
            data: (token) => Column(
              children: [
                // QR widget wrapped for screenshot capture
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2035),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppTheme.primaryBrand.withValues(alpha: 0.2)),
                    ),
                    child: QrImageView(
                      data: token,
                      version: QrVersions.auto,
                      size: 180,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppTheme.primaryBrand,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.white,
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rotates daily · Tap to download',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10),
                ),
                const SizedBox(height: 20),

                // Download button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _downloadQrCode(gymId),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download QR Code',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBrand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQrCode(String gymId) async {
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (bytes == null) return;

      if (kIsWeb) {
        // Web: Downloading files usually requires a different approach (e.g. anchor element or a package)
        // For now, we just skip it or show a message.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Download not supported on Web yet')),
          );
        }
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/amirani_branch_qr_$gymId.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 18),
                SizedBox(width: 10),
                Text('QR Code saved to your documents',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
            backgroundColor: AppTheme.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save QR code')),
        );
      }
    }
  }

  Widget _buildOfflineFallback(BuildContext context) {
    return Column(
      children: [
        _buildDaySelector(),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primaryBrand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.3)),
          ),
          child: const Column(
            children: [
              Icon(Icons.sync_problem, color: AppTheme.primaryBrand, size: 32),
              SizedBox(height: 12),
              Text('Sync Engine Paused',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                  'Reconnect to internet to pull latest achievements and challenge progress.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildDaySelector() {
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final activeDay = ref.watch(activityDaySelectorProvider);
          final isActive = index == activeDay;
          return GestureDetector(
            onTap: () {
              ref.read(activityDaySelectorProvider.notifier).state = index;
            },
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Text(
                  days[index],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isActive ? Colors.white : Colors.white54,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: isActive ? 8 : 6,
                  height: isActive ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isActive ? AppTheme.primaryBrand : Colors.transparent,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                                color: AppTheme.primaryBrand
                                    .withValues(alpha: 0.8),
                                blurRadius: 10)
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAggregatedProgress(SessionProgressState sessionProgress) {
    final progress = sessionProgress.overallProgress;
    final percentage = (progress * 100).toInt();
    final completed = sessionProgress.completedTasks;
    final total = sessionProgress.totalTasks;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Aggregated Progress",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text("Today",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (ctx, bc) {
            final ringSize = (bc.maxWidth * 0.42).clamp(120.0, 168.0);
            return SizedBox(
              height: ringSize,
              width: ringSize,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 8,
                      color: Colors.black.withValues(alpha: 0.5)),
                  CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      color: AppTheme.primaryBrand,
                      strokeCap: StrokeCap.round),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("$percentage%",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28)),
                        const Text("COMPLETED",
                            style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricColumn("Tasks", "$completed/$total"),
              Container(width: 1, height: 32, color: Colors.white10),
              _buildMetricColumn("Calories", "${sessionProgress.consumedCalories}"),
              Container(width: 1, height: 32, color: Colors.white10),
              _buildMetricColumn("Activity", "${sessionProgress.activityMinutes}m"),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHydrationCard(HydrationProgress hydration) {
    final completed = hydration.completedCups;
    final total = hydration.targetCups;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: const DecorationImage(
                    image: CachedNetworkImageProvider(
                        'https://images.unsplash.com/photo-1548839140-29a749e1abc4?w=400'),
                    fit: BoxFit.cover)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Hydration",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text("$completed / $total",
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (ctx, bc) {
                  final dotSize = ((bc.maxWidth - (total - 1) * 6) / total).clamp(8.0, 18.0);
                  return Row(
                    children: List.generate(total, (index) {
                      final isFilled = index < completed;
                      return GestureDetector(
                        onTap: () {
                          ref.read(sessionProgressProvider.notifier).toggleHydrationCup(index);
                        },
                        child: Container(
                          margin: EdgeInsets.only(right: index < (total - 1) ? 6.0 : 0),
                          height: dotSize,
                          width: dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? const Color(0xFF2ECC71) : Colors.black45,
                            boxShadow: isFilled
                                ? [const BoxShadow(color: Color(0xFF2ECC71), blurRadius: 4)]
                                : null,
                            border: isFilled ? null : Border.all(color: Colors.white10),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24)),
            child:
                const Icon(Icons.water_drop, color: Colors.white54, size: 18),
          )
        ],
      ),
    );
  }

  Widget _buildMealTaskCard(MealProgress meal) {
    return _buildHighFidelityMealCard(meal);
  }

  Widget _buildHighFidelityMealCard(MealProgress meal) {
    final timeSuffix = meal.scheduledTime != null ? "${meal.scheduledTime} • " : "";
    final heroIngredient = meal.ingredients.isNotEmpty ? meal.ingredients.first.name : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: meal.isCompleted 
            ? const Color(0xFF2ECC71).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.08)
        ),
        boxShadow: [
          if (!meal.isCompleted)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Row(
        children: [
          // Image / Icon
          Stack(
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(meal.imageUrl.isNotEmpty ? meal.imageUrl : categoryMealImages[meal.mealType] ?? ''),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (meal.isCompleted)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2ECC71),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.black, size: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(meal.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      )),
                    if (!meal.isCompleted)
                      Text(timeSuffix,
                        style: TextStyle(
                          color: AppTheme.primaryBrand.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        )),
                  ],
                ),
                if (heroIngredient != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(heroIngredient,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      )),
                  ),
                const SizedBox(height: 12),
                
                // Macro Badges
                Row(
                  children: [
                    _buildMacroBadge("${meal.calories} kcal", Colors.white, Colors.white10),
                    const SizedBox(width: 8),
                    _buildMacroBadge("P ${meal.protein}g", const Color(0xFF1877F2), const Color(0xFF1877F2).withValues(alpha: 0.1)),
                    const SizedBox(width: 6),
                    _buildMacroBadge("C ${meal.carbs}g", const Color(0xFFF1C40E), const Color(0xFFF1C40E).withValues(alpha: 0.1)),
                    const SizedBox(width: 6),
                    _buildMacroBadge("F ${meal.fats}g", const Color(0xFFEC2A3B), const Color(0xFFEC2A3B).withValues(alpha: 0.1)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        )),
    );
  }

  Widget _buildWorkoutSummaryCard(SessionProgressState session) {
    return _buildTaskCard(
      title: "Workout",
      icon: Icons.fitness_center,
      progressPercent: session.workoutProgress,
      progressLabel: "${session.completedExercises} / ${session.totalExercises} Exercises",
      trailingLabel: session.workoutProgress == 1.0 ? "Finished" : "Active",
      imgUrl: 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400',
    );
  }

  Widget _buildTaskCard({
    required String title,
    required IconData icon,
    required double progressPercent,
    required String progressLabel,
    required String trailingLabel,
    required String imgUrl,
  }) {
    final isDone = progressPercent >= 1.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDone 
            ? const Color(0xFF2ECC71).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                image: DecorationImage(
                    image: CachedNetworkImageProvider(imgUrl), fit: BoxFit.cover)),
            child: isDone ? Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.check, color: Color(0xFF2ECC71), size: 24),
            ) : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDone ? const Color(0xFF2ECC71).withValues(alpha: 0.1) : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(isDone ? "COMPLETED" : "IN PROGRESS",
                        style: TextStyle(
                            color: isDone ? const Color(0xFF2ECC71) : Colors.white38,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progressPercent.clamp(0.0, 1.0),
                    child: Container(
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                            ),
                            borderRadius: BorderRadius.circular(4))),
                  ),
                ),
                const SizedBox(height: 8),
                Text(progressLabel,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Recovery Card ─────────────────────────────────────────────────────────

  Widget _buildRecoveryCard() {
    final recovery = ref.watch(recoveryProvider);
    final entry = recovery.todayEntry;
    final hasEntry = entry != null;

    return GestureDetector(
      onTap: hasEntry
          ? null
          : () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const RecoveryCheckInSheet(),
              );
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: hasEntry
                ? const Color(0xFF2ECC71).withValues(alpha: 0.3)
                : AppTheme.primaryBrand.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: hasEntry
                    ? const Color(0xFF2ECC71).withValues(alpha: 0.15)
                    : AppTheme.primaryBrand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasEntry
                    ? Icons.check_circle_rounded
                    : Icons.self_improvement_rounded,
                color: hasEntry
                    ? const Color(0xFF2ECC71)
                    : AppTheme.primaryBrand,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasEntry ? 'Recovery Logged' : 'Daily Recovery Check-in',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasEntry
                        ? 'Score ${entry.recoveryScore}/100 · '
                            '${entry.sleepHours}h sleep · '
                            'Energy ${entry.energyLevel}/5'
                        : 'Tap to log sleep, energy & soreness',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!hasEntry)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primaryBrand.withValues(alpha: 0.3)),
                ),
                child: const Text('Log',
                    style: TextStyle(
                        color: AppTheme.primaryBrand,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
