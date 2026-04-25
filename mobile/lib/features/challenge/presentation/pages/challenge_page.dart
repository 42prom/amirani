import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import '../../../../core/providers/session_progress_provider.dart';
import '../../../../core/providers/points_provider.dart';
import 'package:amirani_app/core/widgets/user_avatar.dart';
import '../../../profile/presentation/widgets/profile_settings_modal.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';
import 'package:amirani_app/features/workout/presentation/providers/workout_provider.dart';
import '../../../challenge_rooms/presentation/widgets/rooms_tab.dart';
import '../widgets/reward_store_sheet.dart';

class ChallengePage extends ConsumerStatefulWidget {
  const ChallengePage({super.key});

  @override
  ConsumerState<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends ConsumerState<ChallengePage>
    with SingleTickerProviderStateMixin {
  int _activeDay = DateTime.now().weekday - 1;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Ensure progress is synced from local storage on load so the ring is accurate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(sessionProgressProvider.notifier).refreshFromStorage();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileSync = ref.watch(profileSyncProvider);
    final sessionProgress = ref.watch(sessionProgressProvider);
    final points = ref.watch(pointsProvider);

    return Scaffold(
      backgroundColor: AppTokens.colorBgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(profileSync),
            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppTokens.colorBgSurface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTokens.colorBrand.withValues(alpha: 0.25),
                        AppTokens.colorBrand.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTokens.colorBrand.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTokens.colorBrand.withValues(alpha: 0.08),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppTokens.colorBrand,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'My Progress'),
                    Tab(text: 'Rooms'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: existing progress content
                  RefreshIndicator(
                    color: AppTokens.colorBrand,
                    onRefresh: () async {
                      await ref.read(workoutNotifierProvider.notifier).fetchActivePlan();
                      await ref.read(sessionProgressProvider.notifier).syncDown();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDaySelector(),
                          const SizedBox(height: 24),
                          _buildPointsCard(points),
                          const SizedBox(height: 24),
                          _buildAggregatedProgressDashboard(sessionProgress),
                          const SizedBox(height: 32),
                          const Text("Bonus Challenges",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildHydrationTracker(sessionProgress),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                  // Tab 1: Rooms
                  const RoomsTab(),
                ],
              ),
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
                      color: AppTokens.colorBrand,
                      border: Border.all(color: AppTokens.colorBgPrimary, width: 2),
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
              color: AppTokens.colorBgSurface.withValues(alpha: 0.5),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child:
                const Icon(Icons.light_mode, color: Colors.white54, size: 20),
          )
        ],
      ),
    );
  }

  Widget _buildPointsCard(PointsState points) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTokens.colorBrand.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTokens.colorBrand.withValues(alpha: 0.15),
              border: Border.all(color: AppTokens.colorBrand.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.bolt, color: AppTokens.colorBrand, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${points.totalPoints} pts · ${points.levelLabel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  points.streakDays > 0
                      ? '${points.streakDays}-day streak 🔥'
                      : 'Log a meal or workout to start your streak',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => RewardStoreSheet.show(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTokens.colorBrandDim,
                borderRadius: BorderRadius.circular(AppTokens.radius10),
                border: Border.all(color: AppTokens.colorBrandBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Store',
                    style: TextStyle(
                      color: AppTokens.colorBrand,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, color: AppTokens.colorBrand, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final isActive = index == _activeDay;
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeDay = index;
              });
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
                        isActive ? AppTokens.colorBrand : Colors.transparent,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                                color: AppTokens.colorBrand
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

  // --- Hydration Tracker ----------------------------------------------------
  Widget _buildHydrationTracker(SessionProgressState sessionProgress) {
    final hydration = sessionProgress.hydration;
    final isComplete = hydration.isComplete;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: isComplete
                ? Colors.blueAccent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      border: Border.all(
                          color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.water_drop,
                        color: Colors.blueAccent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text("Hydration Today",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              if (isComplete)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("GOAL MET",
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                )
              else
                Text("${hydration.completedCups}/${hydration.targetCups} cups",
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          // Water cups row
          LayoutBuilder(
            builder: (context, constraints) {
              final cupWidth = (constraints.maxWidth - 28) / 8; // 7 gaps of 4px
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(hydration.targetCups, (index) {
                  final isFilled = index < hydration.completedCups;
                  return GestureDetector(
                    onTap: () {
                      ref
                          .read(sessionProgressProvider.notifier)
                          .toggleHydrationCup(index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: cupWidth.clamp(28.0, 40.0),
                      height: cupWidth.clamp(28.0, 40.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? Colors.blueAccent.withValues(alpha: 0.1)
                            : Colors.transparent,
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                    color: Colors.blueAccent
                                        .withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    spreadRadius: 2)
                              ]
                            : null,
                      ),
                      child: Icon(
                        isFilled ? Icons.water_drop : Icons.water_drop_outlined,
                        color: isFilled
                            ? Colors.blueAccent
                            : Colors.white.withValues(alpha: 0.2),
                        size: cupWidth.clamp(22.0, 28.0),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
              isComplete
                  ? "Great job staying hydrated!"
                  : "Tap a cup to log water intake",
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  // --- Session-based Progress Cards -----------------------------------------
  Widget _buildAggregatedProgressDashboard(
      SessionProgressState sessionProgress) {
    final dailyScore = sessionProgress.dailyScore;
    final overallProgress = dailyScore / 100.0;
    final workoutProgress = sessionProgress.workoutProgress;
    final dietProgress = sessionProgress.dietProgress;

    final completedExercises = sessionProgress.completedExercises;
    final totalExercises = sessionProgress.totalExercises;
    final completedMeals = sessionProgress.completedMeals;
    final totalMeals = sessionProgress.totalMeals;
    final consumedCalories = sessionProgress.consumedCalories;

    final isComplete = dailyScore >= 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("Today",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Progress Visualization
          LayoutBuilder(builder: (ctx, bc) {
            final ringSize = (bc.maxWidth * 0.44).clamp(130.0, 185.0);
            return SizedBox(
              height: ringSize,
              width: ringSize,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isComplete) ...[
                  // Solid Green Success Point
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2ECC71),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2ECC71).withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.emoji_events,
                      color: Color(0xFFF1C40E),
                      size: 90,
                    ),
                  ),
                ] else ...[
                  // Multi-ring circular progress
                  // Workout Outer Ring
                  CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 12,
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeCap: StrokeCap.round),
                  CircularProgressIndicator(
                      value: workoutProgress,
                      strokeWidth: 12,
                      color: completedExercises >= totalExercises &&
                              totalExercises > 0
                          ? const Color(0xFF2ECC71) // Green when 100%
                          : workoutProgress >= 0.5
                              ? Colors.blueAccent // Blue when > 50%
                              : const Color(0xFFF1C40E), // Gold when < 50%
                      strokeCap: StrokeCap.round),

                  // Diet Inner Ring
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 12,
                            color: Colors.white.withValues(alpha: 0.05),
                            strokeCap: StrokeCap.round),
                        CircularProgressIndicator(
                            value: dietProgress,
                            strokeWidth: 12,
                            color: completedMeals >= totalMeals &&
                                    totalMeals > 0
                                ? const Color(0xFF2ECC71) // Green when 100%
                                : dietProgress >= 0.5
                                    ? Colors.blueAccent // Blue when > 50%
                                    : Colors.orangeAccent, // Orange when < 50%
                            strokeCap: StrokeCap.round),
                      ],
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${(overallProgress * 100).round()}%",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 32)),
                        Text("TOTAL",
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
          }),
          const SizedBox(height: 32),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRefinedStatItem(
                "Workout",
                totalExercises > 0
                    ? "$completedExercises/$totalExercises"
                    : "Rest Day",
                const Color(0xFFF1C40E),
                Icons.fitness_center,
              ),
              _buildRefinedStatItem(
                "Calories",
                consumedCalories.toString(),
                Colors.white70,
                Icons.bolt,
              ),
              _buildRefinedStatItem(
                "Diet",
                "$completedMeals/$totalMeals",
                Colors.orangeAccent,
                Icons.restaurant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefinedStatItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.4), size: 16),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
