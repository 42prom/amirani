import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/diet_provider.dart';
import '../providers/diet_onboarding_provider.dart';
import '../providers/food_provider.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../../../../core/providers/session_progress_provider.dart';
import '../../../../core/services/diet_plan_storage_service.dart';
import '../../../../core/services/meal_swap_service.dart';
import '../../domain/entities/daily_macro_entity.dart';
import '../../domain/entities/monthly_plan_entity.dart' as plan_entity;
import '../providers/shopping_basket_provider.dart';
import '../../domain/entities/diet_preferences_entity.dart';
import '../../../profile/presentation/widgets/profile_settings_modal.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';
import '../../../gym/presentation/providers/trainer_assignment_provider.dart';
import 'package:amirani_app/core/widgets/plan_source_badge.dart';
import '../../../../core/providers/tier_limits_provider.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/providers/day_selector_providers.dart';
import '../../../../core/utils/app_notifications.dart';
import '../../../../core/providers/diet_profile_sync_provider.dart';
import '../../../../core/providers/points_provider.dart';
import 'diet_onboarding_page.dart';
import 'package:amirani_app/core/widgets/premium_state_card.dart';
import '../../../../core/utils/food_emoji_registry.dart';
import 'package:amirani_app/core/widgets/user_avatar.dart';
import 'package:amirani_app/core/widgets/app_day_selector.dart';

// Note: generatedDietPlanProvider moved to diet_provider.dart

class DietPage extends ConsumerStatefulWidget {
  const DietPage({super.key});

  @override
  ConsumerState<DietPage> createState() => _DietPageState();
}

class _DietPageState extends ConsumerState<DietPage> {
  final Set<String> _expandedMeals = {};

  /// Cached macros from the last DietLoaded state — keeps content visible
  /// during AI plan generation instead of replacing the screen with a spinner.
  DailyMacroEntity? _lastMacros;

  /// Expand allergy types to actual food names that should be excluded
  /// This ensures lactose intolerance filters ALL dairy, not just "lactose"
  List<String> _expandAllergiesToFoods(List<UserAllergyEntity>? allergies) {
    if (allergies == null || allergies.isEmpty) return [];

    final foods = <String>[];
    for (final allergy in allergies) {
      switch (allergy.type) {
        case AllergyType.lactose:
          foods.addAll([
            'yogurt',
            'cheese',
            'milk',
            'butter',
            'cream',
            'dairy',
            'mozzarella',
            'cheddar',
            'parmesan',
            'feta',
            'cottage cheese',
            'labneh',
            'kefir',
            'ghee',
            'whey',
          ]);
          break;
        case AllergyType.gluten:
          foods.addAll([
            'bread',
            'pasta',
            'wheat',
            'oatmeal',
            'barley',
            'rye',
            'crackers',
            'cereal',
            'flour',
            'couscous'
          ]);
          break;
        case AllergyType.peanuts:
          foods.addAll(['peanuts', 'peanut butter', 'peanut']);
          break;
        case AllergyType.treeNuts:
          foods.addAll([
            'almond',
            'almonds',
            'walnut',
            'walnuts',
            'cashew',
            'cashews',
            'pistachio',
            'pistachios',
            'hazelnut',
            'hazelnuts',
            'pecan',
            'pecans',
            'macadamia',
            'nuts',
          ]);
          break;
        case AllergyType.shellfish:
          foods.addAll([
            'shrimp',
            'crab',
            'lobster',
            'clams',
            'mussels',
            'oysters',
            'scallops',
            'shellfish'
          ]);
          break;
        case AllergyType.fish:
          foods.addAll(['fish', 'salmon', 'tuna', 'cod', 'tilapia', 'seafood']);
          break;
        case AllergyType.eggs:
          foods.addAll(['eggs', 'egg', 'mayonnaise']);
          break;
        case AllergyType.soy:
          foods.addAll(['tofu', 'soy', 'soy sauce', 'edamame', 'tempeh']);
          break;
        case AllergyType.wheat:
          foods.addAll(['wheat', 'bread', 'pasta', 'flour', 'crackers']);
          break;
        case AllergyType.sesame:
          foods.addAll(['sesame', 'tahini', 'sesame seeds']);
          break;
        case AllergyType.other:
          if (allergy.customName != null) {
            foods.add(allergy.customName!.toLowerCase());
          }
          break;
      }
    }
    return foods.toSet().toList(); // Remove duplicates
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // fetchActivePlan handles offline-first loading and trainer plan checks.
      // It replaces our multi-step manual loading for a smoother experience.
      ref.read(dietNotifierProvider.notifier).fetchActivePlan();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _toggleMealExpanded(String mealId) {
    setState(() {
      if (_expandedMeals.contains(mealId)) {
        _expandedMeals.remove(mealId);
      } else {
        _expandedMeals.add(mealId);
      }
    });
  }

  Future<void> _showNewTrainerDietPlanDialog(DietNewTrainerPlan newPlan) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBrand.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu,
                  color: AppTheme.primaryBrand, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'New Diet Plan Assigned',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your trainer has assigned you a new diet plan:',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryBrand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primaryBrand.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    newPlan.plan.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${newPlan.plan.targetCalories} kcal · P${newPlan.plan.targetProtein}g  C${newPlan.plan.targetCarbs}g  F${newPlan.plan.targetFats}g',
                    style: const TextStyle(
                        color: AppTheme.primaryBrand,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(dietNotifierProvider.notifier).dismissNewPlan();
            },
            child: Text('Later',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBrand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(dietNotifierProvider.notifier)
                  .acceptNewPlan(newPlan.plan, newPlan.monthly);
            },
            child: const Text('Load Plan',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeDay = ref.watch(dietDaySelectorProvider);
    final state = ref.watch(dietNotifierProvider);
    final profileState = ref.watch(profileSyncProvider);
    final dietProfileSync = ref.watch(dietProfileSyncProvider);

    // Show acceptance prompt when trainer assigns a new diet plan
    ref.listen<DietState>(dietNotifierProvider, (_, next) {
      if (next is DietNewTrainerPlan && mounted) {
        _showNewTrainerDietPlanDialog(next);
      }
    });

    // Auto-reload meals when the overall plan changes (sync, acceptance, etc.)
    ref.listen<plan_entity.MonthlyDietPlanEntity?>(generatedDietPlanProvider,
        (prev, next) {
      if (next != null && mounted) {
        _loadMealsForDay(ref.read(dietDaySelectorProvider), next);
      }
    });

    // Auto-reload meals when day changes (e.g. from nav shell resetting to today)
    ref.listen<int>(dietDaySelectorProvider, (prev, next) {
      if (prev != next) {
        final plan = ref.read(generatedDietPlanProvider);
        if (plan != null && mounted) _loadMealsForDay(next, plan);
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      floatingActionButton: _buildAIFloatingButton(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(profileState),
            // Profile change recalculation banner
            if (dietProfileSync.needsRecalculation)
              _buildRecalculationBanner(dietProfileSync.changeReason),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref
                      .read(dietNotifierProvider.notifier)
                      .fetchActivePlan();
                  await ref.read(sessionProgressProvider.notifier).syncDown();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: _buildBody(state, context, activeDay),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIFloatingButton() {
    return FloatingActionButton(
      onPressed: () {
        _showAIDietDialog();
      },
      shape: const CircleBorder(),
      backgroundColor: AppTheme.primaryBrand,
      elevation: 8,
      child: const Icon(Icons.auto_awesome, color: Colors.black, size: 28),
    );
  }

  /// Banner shown when profile changes affect diet calculations
  Widget _buildRecalculationBanner(String? changeReason) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primaryBrand.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBrand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: AppTheme.primaryBrand, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Optimize Your Plan",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            changeReason ?? "Profile updates detected",
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        ref
                            .read(dietProfileSyncProvider.notifier)
                            .dismissRegenerationPrompt();
                      },
                      icon: Icon(
                        Icons.close,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref
                          .read(dietProfileSyncProvider.notifier)
                          .triggerPlanRegeneration();
                      _launchDietOnboarding();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBrand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "RECALCULATE DIET",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchDietOnboarding() async {
    // Reset onboarding state before starting
    ref.read(dietOnboardingProvider.notifier).reset();

    final result =
        await showModalBottomSheet<plan_entity.MonthlyDietPlanEntity>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => const DietOnboardingPage(),
    );

    // If a plan was generated, save it and update the view
    if (result != null && mounted) {
      // Store the generated plan
      ref.read(generatedDietPlanProvider.notifier).state = result;
      ref.read(dietPlanIsAIGeneratedProvider.notifier).state = true;

      // Update session progress with selected day's meals from the plan
      _loadMealsForDay(ref.read(dietDaySelectorProvider), result);

      // Refresh the diet view
      ref.read(dietNotifierProvider.notifier).fetchDailyMacros(DateTime.now());
      // Sync with backend so storage gets the authoritative UUID-based plan,
      // preventing the "reverts to different plan on refresh" bug.
      unawaited(ref.read(dietNotifierProvider.notifier).fetchActivePlan());
    }
  }

  /// Load meals for a specific day from the plan into session progress.
  /// This maps the 0-6 index (Mon-Sun) to the actual calendar dates of the CURRENT week.
  void _loadMealsForDay(int dayIndex, plan_entity.MonthlyDietPlanEntity plan) {
    final now = DateTime.now();
    // Normalization: Find the Monday of the current week
    final mondayOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final targetDate = DateTime(
      mondayOfThisWeek.year,
      mondayOfThisWeek.month,
      mondayOfThisWeek.day + dayIndex,
    );

    ref.read(sessionProgressProvider.notifier).loadDay(targetDate, plan);
  }

  void _showAIDietDialog() {
    final limits = ref.read(tierLimitsProvider).valueOrNull;
    if (limits != null) {
      if (limits.isOfflineFallback) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Unable to verify your plan access. Please check your connection and try again.'),
          backgroundColor: Colors.orangeAccent.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        return;
      }
      if (!limits.canAccessDietPlanner) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'AI Diet Planner requires a Premium or Gym Member plan'),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        return;
      }
      if (!limits.canMakeRequest) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(limits.remainingLabel),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        return;
      }
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => _AIDietAssistantModal(
        onLaunchOnboarding: _launchDietOnboarding,
        onShowSwapMeal: _showSwapMealDialog,
      ),
    );
  }

  /// Show swap meal dialog - select meal then choose alternative
  void _showSwapMealDialog() {
    final plan = ref.read(generatedDietPlanProvider);
    final sessionProgress = ref.read(sessionProgressProvider);

    // Block swapping for trainer-assigned plans
    final isAIGenerated = ref.read(dietPlanIsAIGeneratedProvider);
    if (!isAIGenerated) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF131722),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    color: AppTheme.primaryBrand, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                "Swapping Not Available",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "Meal swapping is disabled for trainer-assigned diet plans to ensure your results stay consistent with their specific prescriptions.",
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBrand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("I Understand",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (plan == null && sessionProgress.meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No diet plan available. Generate a plan first.'),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Get today's meals from session progress
    final meals = sessionProgress.meals;
    if (meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No meals available for today.'),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (modalContext) => Material(
        color: Colors.transparent,
        child: Container(
          height: MediaQuery.of(modalContext).size.height * 0.85,
          margin: const EdgeInsets.only(top: 24),
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark.withValues(alpha: 0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        const SizedBox(width: 48, height: 48),
                        const Spacer(),
                        // Close Button
                        IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 28),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Swap Meal",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Select a meal to replace",
                            style:
                                TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          // Swap All Button
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(modalContext);
                              _showSwapAllConfirmDialog(meals, plan);
                            },
                            child: _buildSwapAllOptionContent(meals),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            "OR SELECT INDIVIDUAL",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Individual Meals
                          ...meals.map((meal) => GestureDetector(
                                onTap: () {
                                  Navigator.pop(modalContext);
                                  _showAlternativesDialog(meal, plan);
                                },
                                child: _buildSwapMealOptionContent(meal),
                              )),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwapAllOptionContent(List<MealProgress> meals) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBrand.withValues(alpha: 0.2),
            AppTheme.primaryBrand.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBrand.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.autorenew,
                color: AppTheme.primaryBrand, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Swap All Meals",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text("Replace all ${meals.length} meals with alternatives",
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBrand,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: Colors.black, size: 16),
                SizedBox(width: 4),
                Text("AI",
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSwapAllConfirmDialog(
      List<MealProgress> meals, plan_entity.MonthlyDietPlanEntity? plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (modalContext) => Material(
        color: Colors.transparent,
        child: Container(
          height: MediaQuery.of(modalContext).size.height * 0.6,
          margin: const EdgeInsets.only(top: 24),
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark.withValues(alpha: 0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 28),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryBrand.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.autorenew,
                                color: AppTheme.primaryBrand, size: 40),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Swap All Meals?",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "This will replace all ${meals.length} meals with new alternatives based on your dietary preferences.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 16),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(modalContext);
                                _executeSwapAll(meals, plan);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBrand,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "Swap All Meals",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.pop(modalContext),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _executeSwapAll(
      List<MealProgress> meals, plan_entity.MonthlyDietPlanEntity? plan) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            ),
            SizedBox(width: 12),
            Text('Generating new meals...'),
          ],
        ),
        backgroundColor: AppTheme.primaryBrand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    // Get preferences and swap service
    final storage = ref.read(dietPlanStorageProvider);
    final prefs = await storage.loadPreferences();
    final dietaryStyle = prefs?.dietaryStyle ?? DietaryStyle.noRestrictions;
    final mealSwapService = ref.read(mealSwapServiceProvider);
    final likedFoods = prefs?.likedFoods ?? <String>[];
    // Combine disliked foods with expanded allergies (lactose → all dairy, etc.)
    final expandedAllergies = _expandAllergiesToFoods(prefs?.allergies);
    final dislikedFoods = <String>[
      ...(prefs?.dislikedFoods ?? []),
      ...expandedAllergies
    ];

    final updatedMeals = <MealProgress>[];

    for (final meal in meals) {
      final entityMealType = _sessionToEntityMealType(meal.mealType);

      final tempMeal = plan_entity.PlannedMealEntity(
        id: meal.mealId,
        type: entityMealType,
        name: meal.name,
        description: meal.description,
        ingredients: const [],
        instructions: '',
        prepTimeMinutes: 0,
        nutrition: plan_entity.NutritionInfoEntity(
          calories: meal.calories,
          protein: meal.protein,
          carbs: meal.carbs,
          fats: meal.fats,
        ),
      );

      // Get alternatives matching calories, fat, and carbs to preserve daily macro ratio
      final alternatives = mealSwapService.getAlternatives(
        mealType: entityMealType,
        dietaryStyle: dietaryStyle,
        currentMeal: tempMeal,
        dislikedFoods: dislikedFoods,
        likedFoods: likedFoods,
        targetCalories: meal.calories,
        targetFats: meal.fats,
        targetCarbs: meal.carbs,
        count: 3,
      );

      if (alternatives.isNotEmpty) {
        // Service already sorts by preference, so first is best match
        final selectedAlt = alternatives.first;

        updatedMeals.add(MealProgress(
          mealId: meal.mealId,
          mealType: meal.mealType,
          name: selectedAlt.name,
          description: selectedAlt.description,
          calories: selectedAlt.calories,
          protein: selectedAlt.protein,
          carbs: selectedAlt.carbs,
          fats: selectedAlt.fats,
          imageUrl: selectedAlt.imageUrl,
          isCompleted: false,
          ingredients: selectedAlt.ingredients.map((ing) {
            return MealIngredient(
              ingredientId: 'ing_${ing.name.hashCode}',
              name: ing.name,
              portion: '${ing.amount} ${ing.unit}',
              calories: ing.calories,
              protein: ing.protein,
              carbs: ing.carbs,
              fats: ing.fats,
            );
          }).toList(),
        ));

        if (plan != null) {
          final selectedDate = ref.read(sessionProgressProvider).date;
          await mealSwapService.swapMeal(
            plan: plan,
            date: selectedDate,
            mealType: entityMealType,
            newMeal: selectedAlt,
          );
        }
      } else {
        updatedMeals.add(meal);
      }
    }

    ref.read(sessionProgressProvider.notifier).setMeals(updatedMeals);

    // Reload plan
    final updatedPlan = await storage.loadPlan();
    if (updatedPlan != null) {
      ref.read(generatedDietPlanProvider.notifier).state = updatedPlan;
    }

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.black, size: 20),
              const SizedBox(width: 12),
              Text('All ${meals.length} meals swapped!'),
            ],
          ),
          backgroundColor: const Color(0xFF2ECC71),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildSwapMealOptionContent(MealProgress meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black45,
              border: Border.all(color: Colors.white10),
              image: DecorationImage(
                image: NetworkImage(meal.imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getMealTypeLabel(meal.mealType),
                    style: TextStyle(
                        color: AppTheme.primaryBrand.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(meal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                Text("${meal.calories} kcal",
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBrand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.swap_horiz,
                color: AppTheme.primaryBrand, size: 20),
          ),
        ],
      ),
    );
  }

  String _getMealTypeLabel(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return 'BREAKFAST';
      case MealType.lunch:
        return 'LUNCH';
      case MealType.dinner:
        return 'DINNER';
      case MealType.snack:
        return 'SNACK';
      case MealType.morningSnack:
        return 'MORNING SNACK';
      case MealType.afternoonSnack:
        return 'AFTERNOON SNACK';
    }
  }

  plan_entity.MealType _sessionToEntityMealType(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return plan_entity.MealType.breakfast;
      case MealType.lunch:
        return plan_entity.MealType.lunch;
      case MealType.dinner:
        return plan_entity.MealType.dinner;
      case MealType.snack:
        return plan_entity.MealType.snack;
      case MealType.morningSnack:
        return plan_entity.MealType.morningSnack;
      case MealType.afternoonSnack:
        return plan_entity.MealType.afternoonSnack;
    }
  }

  void _showAlternativesDialog(
      MealProgress currentMeal, plan_entity.MonthlyDietPlanEntity? plan) {
    // Get dietary style from saved preferences or default
    final storage = ref.read(dietPlanStorageProvider);

    storage.loadPreferences().then((prefs) {
      final dietaryStyle = prefs?.dietaryStyle ?? DietaryStyle.noRestrictions;
      final likedFoods = prefs?.likedFoods ?? <String>[];
      // Combine disliked foods with expanded allergies (lactose → all dairy, etc.)
      final expandedAllergies = _expandAllergiesToFoods(prefs?.allergies);
      final dislikedFoods = <String>[
        ...(prefs?.dislikedFoods ?? []),
        ...expandedAllergies
      ];
      final mealSwapService = ref.read(mealSwapServiceProvider);

      // Convert to plan entity MealType
      final entityMealType = _sessionToEntityMealType(currentMeal.mealType);

      // Create a temporary PlannedMealEntity for the service
      final tempMeal = plan_entity.PlannedMealEntity(
        id: currentMeal.mealId,
        type: entityMealType,
        name: currentMeal.name,
        description: currentMeal.description,
        ingredients: const [],
        instructions: '',
        prepTimeMinutes: 0,
        nutrition: plan_entity.NutritionInfoEntity(
          calories: currentMeal.calories,
          protein: currentMeal.protein,
          carbs: currentMeal.carbs,
          fats: currentMeal.fats,
        ),
      );

      // Get alternatives matching calories, fat, and carbs to preserve daily macro ratio
      final alternatives = mealSwapService.getAlternatives(
        mealType: entityMealType,
        dietaryStyle: dietaryStyle,
        currentMeal: tempMeal,
        dislikedFoods: dislikedFoods,
        likedFoods: likedFoods,
        targetCalories: currentMeal.calories,
        targetFats: currentMeal.fats,
        targetCarbs: currentMeal.carbs,
        count: 3,
      );

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useRootNavigator: true,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        builder: (modalContext) => Material(
          color: Colors.transparent,
          child: Container(
            height: MediaQuery.of(modalContext).size.height * 0.85,
            margin: const EdgeInsets.only(top: 24),
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark.withValues(alpha: 0.7),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          // Back Button
                          IconButton(
                            onPressed: () {
                              Navigator.pop(modalContext);
                              _showSwapMealDialog();
                            },
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white, size: 28),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const Spacer(),
                          // Close Button
                          IconButton(
                            onPressed: () => Navigator.pop(modalContext),
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 28),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Choose Alternative",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Replacing: ${currentMeal.name}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 14),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                const Text(
                                  "ALTERNATIVES",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBrand
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getDietaryStyleLabel(dietaryStyle),
                                    style: const TextStyle(
                                      color: AppTheme.primaryBrand,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (alternatives.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Text(
                                    "No alternatives available",
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ),
                              )
                            else
                              ...alternatives.map((alt) =>
                                  _buildAlternativeCard(alt, currentMeal, plan,
                                      entityMealType, modalContext)),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  String _getDietaryStyleLabel(DietaryStyle style) {
    switch (style) {
      case DietaryStyle.vegan:
        return 'VEGAN';
      case DietaryStyle.vegetarian:
        return 'VEGETARIAN';
      case DietaryStyle.keto:
        return 'KETO';
      case DietaryStyle.mediterranean:
        return 'MEDITERRANEAN';
      case DietaryStyle.pescatarian:
        return 'PESCATARIAN';
      case DietaryStyle.halal:
        return 'HALAL';
      case DietaryStyle.kosher:
        return 'KOSHER';
      default:
        return 'STANDARD';
    }
  }

  Widget _buildAlternativeCard(
    MealAlternative alt,
    MealProgress currentMeal,
    plan_entity.MonthlyDietPlanEntity? plan,
    plan_entity.MealType mealType,
    BuildContext modalContext,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(modalContext);
        _executeSwap(alt, currentMeal, plan, mealType);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black45,
                    border: Border.all(color: Colors.white10),
                    image: DecorationImage(
                      image: NetworkImage(alt.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alt.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(alt.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildNutritionChip(Icons.local_fire_department,
                    "${alt.calories} kcal", AppTheme.primaryBrand),
                const SizedBox(width: 12),
                _buildNutritionChip(Icons.timer_outlined, "${alt.prepTime} min",
                    Colors.blueAccent),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBrand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.swap_horiz, color: Colors.black, size: 18),
                      SizedBox(width: 6),
                      Text("Swap",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _executeSwap(
    MealAlternative newMeal,
    MealProgress currentMeal,
    plan_entity.MonthlyDietPlanEntity? plan,
    plan_entity.MealType mealType,
  ) async {
    // Note: caller already popped the alternatives sheet — do NOT pop again here

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            Text('Swapping to ${newMeal.name}...'),
          ],
        ),
        backgroundColor: AppTheme.primaryBrand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );

    // Update plan if exists
    if (plan != null) {
      final mealSwapService = ref.read(mealSwapServiceProvider);
      final updatedPlan = await mealSwapService.swapMeal(
        plan: plan,
        date: DateTime.now(),
        mealType: mealType,
        newMeal: newMeal,
      );

      if (updatedPlan != null) {
        ref.read(generatedDietPlanProvider.notifier).state = updatedPlan;
      }
    }

    // Update session progress immediately
    final sessionMeals = ref.read(sessionProgressProvider).meals;
    final updatedMeals = sessionMeals.map((meal) {
      if (meal.mealId == currentMeal.mealId) {
        return MealProgress(
          mealId: meal.mealId,
          mealType: meal.mealType,
          name: newMeal.name,
          description: newMeal.description,
          calories: newMeal.calories,
          protein: newMeal.protein,
          carbs: newMeal.carbs,
          fats: newMeal.fats,
          imageUrl: newMeal.imageUrl,
          isCompleted: meal.isCompleted,
          ingredients: newMeal.ingredients.map((ing) {
            return MealIngredient(
              ingredientId: 'ing_${ing.name.hashCode}',
              name: ing.name,
              portion: '${ing.amount} ${ing.unit}',
              calories: ing.calories,
              protein: ing.protein,
              carbs: ing.carbs,
              fats: ing.fats,
            );
          }).toList(),
        );
      }
      return meal;
    }).toList();

    ref.read(sessionProgressProvider.notifier).setMeals(updatedMeals);

    // Show success
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.black, size: 20),
              const SizedBox(width: 12),
              Text('Swapped to ${newMeal.name}'),
            ],
          ),
          backgroundColor: const Color(0xFF2ECC71),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildHeader(ProfileSyncState profileState) {
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
                  imagePath: profileState.profileImagePath,
                  displayName: profileState.fullName,
                  size: 40,
                  badge: Container(
                    height: 12,
                    width: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryBrand,
                      border:
                          Border.all(color: AppTheme.backgroundDark, width: 2),
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
                      profileState.firstName.isNotEmpty
                          ? profileState.firstName
                          : (profileState.fullName.isNotEmpty
                              ? profileState.fullName.split(' ')[0]
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child:
                const Icon(Icons.light_mode, color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(DietState state, BuildContext context, int activeDay) {
    final sessionProgress = ref.watch(sessionProgressProvider);
    final plan = ref.watch(generatedDietPlanProvider);

    if (state is DietLoading) {
      // Use session progress while loading
      if (sessionProgress.meals.isNotEmpty) {
        return _buildSessionDietView(sessionProgress, activeDay);
      }
      return Column(
        children: [
          _buildUnifiedDaySelector(activeDay),
          const SizedBox(height: 100),
          const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBrand)),
        ],
      );
    }

    if (state is DietError) {
      // Prefer session progress for offline/dev mode
      if (sessionProgress.meals.isNotEmpty) {
        return _buildSessionDietView(sessionProgress, activeDay);
      }
      // Live fallback: if local plan exists, use it despite the error
      if (plan != null) {
        Future.microtask(() => _loadMealsForDay(activeDay, plan));
        return _buildSessionDietView(sessionProgress, activeDay);
      }
      // Generation failed/timed out — offer a retry button instead of a dead offline card.
      if (state.canRetry) {
        return _buildRetryGenerationError(context, state.message);
      }
      return _buildOfflineFallback(context);
    }

    if (state is DietLoaded) {
      // Cache macros so DietGenerating can keep content visible
      _lastMacros = state.macros;

      // Prefer session progress for live tracking
      if (sessionProgress.meals.isNotEmpty) {
        return _buildSessionDietView(sessionProgress, activeDay);
      }

      // Live fallback: if session meals are empty (e.g. after model refresh)
      // but plan is available, populate immediately.
      if (plan != null) {
        Future.microtask(() => _loadMealsForDay(activeDay, plan));
        return _buildSessionDietView(sessionProgress, activeDay);
      }

      final macros = state.macros;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUnifiedDaySelector(activeDay),
          const SizedBox(height: 24),
          _buildTodayMacros(macros),
          const SizedBox(height: 32),
          _buildMealsHeader(),
          const SizedBox(height: 16),
          _buildEmptyMealsState(context, plan: plan, activeDay: activeDay),
        ],
      );
    }

    if (state is DietGenerating) {
      // Keep current content visible — just add a slim status banner at the top.
      final cached = _lastMacros;
      final plan = ref.watch(generatedDietPlanProvider);
      if (cached != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGeneratingBanner(),
            _buildUnifiedDaySelector(activeDay),
            const SizedBox(height: 24),
            _buildTodayMacros(cached),
            const SizedBox(height: 32),
            _buildMealsHeader(),
            const SizedBox(height: 16),
            _buildEmptyMealsState(context, plan: plan, activeDay: activeDay),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGeneratingBanner(),
          const SizedBox(height: 60),
          const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBrand)),
        ],
      );
    }

    // DietInitial / any unhandled state — always show day selector + CTA.
    if (sessionProgress.meals.isNotEmpty) {
      return _buildSessionDietView(sessionProgress, activeDay);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUnifiedDaySelector(activeDay),
        const SizedBox(height: 24),
        _buildNoPlanCTA(context),
      ],
    );
  }

  Widget _buildGeneratingBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryBrand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primaryBrand),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Generating your personalised plan…',
              style: TextStyle(
                  color: AppTheme.primaryBrand,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPlanCTA(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryBrand.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppTheme.primaryBrand, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('No Plan Active',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Create your personalised nutrition plan using AI.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRetryGenerationError(BuildContext context, String message) {
    return Column(
      children: [
        _buildUnifiedDaySelector(ref.read(dietDaySelectorProvider)),
        const SizedBox(height: 24),
        PremiumStateCard(
          icon: Icons.error_outline_rounded,
          title: 'Generation Failed',
          subtitle: message,
          actionLabel: 'Try Again',
          onAction: () => ref.read(dietNotifierProvider.notifier).generateDietPlan(),
        ),
      ],
    );
  }

  Widget _buildOfflineFallback(BuildContext context) {
    return Column(
      children: [
        _buildUnifiedDaySelector(ref.read(dietDaySelectorProvider)),
        const SizedBox(height: 24),
        const PremiumStateCard(
          icon: Icons.cloud_off_rounded,
          title: 'Cannot load Diet Plan',
          subtitle: 'You are working offline with no cached data for this day.',
        )
      ],
    );
  }

  Widget _buildUnifiedDaySelector(int activeDay) {
    final plan = ref.watch(generatedDietPlanProvider);
    final now = DateTime.now();
    final mondayOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final Set<int> daysWithTasks = {};

    if (plan != null) {
      final normalizedStart = DateTime(
          plan.startDate.year, plan.startDate.month, plan.startDate.day);
      for (int i = 0; i < 7; i++) {
        final targetDate = DateTime(
          mondayOfThisWeek.year,
          mondayOfThisWeek.month,
          mondayOfThisWeek.day + i,
        );
        final normalizedTarget =
            DateTime(targetDate.year, targetDate.month, targetDate.day);

        if (!normalizedTarget.isBefore(normalizedStart) &&
            plan.getDayPlan(targetDate) != null) {
          daysWithTasks.add(i);
        }
      }
    }

    return AppDaySelector(
      activeDay: activeDay,
      onDaySelected: (index) {
        ref.read(dietDaySelectorProvider.notifier).state = index;
        if (plan != null) {
          _loadMealsForDay(index, plan);
        }
      },
      daysWithTasks: daysWithTasks,
    );
  }

  Widget _buildTodayMacros(DailyMacroEntity macros) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Today's Macros",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primaryBrand.withValues(alpha: 0.2))),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: AppTheme.primaryBrand, size: 14),
                  SizedBox(width: 4),
                  Text("ON TRACK",
                      style: TextStyle(
                          color: AppTheme.primaryBrand,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Calories Remaining",
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              "${macros.targetCalories - macros.currentCalories}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold)),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6.0, left: 4.0),
                            child: Text("kcal",
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12)),
                    child: const Icon(Icons.local_fire_department,
                        color: AppTheme.primaryBrand, size: 24),
                  )
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMacroBar("Protein", macros.currentProtein,
                      macros.targetProtein, AppTheme.primaryBrand),
                  const SizedBox(width: 16),
                  _buildMacroBar("Carbs", macros.currentCarbs,
                      macros.targetCarbs, Colors.blueAccent),
                  const SizedBox(width: 16),
                  _buildMacroBar("Fats", macros.currentFats, macros.targetFats,
                      Colors.greenAccent),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroBar(String label, int current, int target, Color color) {
    double progress = target > 0 ? (current / target) : 0.0;
    if (progress > 1.0) progress = 1.0;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              Text("${current}g",
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.white10, borderRadius: BorderRadius.circular(4)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text("Goal: ${target}g",
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMealsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Meals",
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text("Log Meal",
            style: TextStyle(
                color: AppTheme.primaryBrand.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- Session-based Diet View (with live tracking) -------------------------
  Widget _buildSessionDietView(
      SessionProgressState sessionProgress, int activeDay) {
    final now = DateTime.now();
    final todayWeekday = now.weekday - 1; // 0-6 (Mon-Sun)

    final isTodaySelected = activeDay == todayWeekday;
    final isPastDay = activeDay < todayWeekday;
    final isFutureDay = activeDay > todayWeekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUnifiedDaySelector(activeDay),
        const SizedBox(height: 24),
        _buildSessionMacros(sessionProgress),
        const SizedBox(height: 32),
        _buildSessionMealsHeader(sessionProgress),
        const SizedBox(height: 16),
        ...sessionProgress.meals.map((meal) => _buildInteractiveMealCard(
              meal,
              isTodaySelected: isTodaySelected,
              isPastDay: isPastDay,
              isFutureDay: isFutureDay,
            )),
        if (isTodaySelected) ...[
          const SizedBox(height: 32),
          _buildFoodLogSection(),
        ],
      ],
    );
  }

  Widget _buildFoodLogSection() {
    final today = DateTime.now();
    final diaryDate =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final diaryAsync = ref.watch(foodDiaryProvider(diaryDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Food Log',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            GestureDetector(
              onTap: () => context.push('/diet/food-search',
                  extra: {'mealType': 'SNACK', 'diaryDate': diaryDate}),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primaryBrand.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: AppTheme.primaryBrand, size: 14),
                    SizedBox(width: 4),
                    Text('Add Food',
                        style: TextStyle(
                            color: AppTheme.primaryBrand,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        diaryAsync.when(
          loading: () => const Center(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(
                color: AppTheme.primaryBrand, strokeWidth: 2),
          )),
          error: (_, __) => const SizedBox.shrink(),
          data: (diary) {
            if (diary.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.restaurant_outlined,
                        color: Colors.white.withValues(alpha: 0.25), size: 32),
                    const SizedBox(height: 8),
                    Text('No food logged today',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13)),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final group in diary.meals)
                  if (group.entries.isNotEmpty)
                    _buildFoodDiaryGroup(group, diaryDate),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFoodDiaryGroup(
      dynamic group, String diaryDate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _capitalizeMealType(group.mealType as String),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                Text(
                  '${(group.totalCalories as double).toStringAsFixed(0)} kcal',
                  style: TextStyle(
                      color: AppTheme.primaryBrand,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          for (final entry in group.entries as List)
            _buildFoodLogEntryRow(entry, diaryDate),
          GestureDetector(
            onTap: () => context.push('/diet/food-search', extra: {
              'mealType': group.mealType as String,
              'diaryDate': diaryDate,
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text('+ Add to ${_capitalizeMealType(group.mealType as String)}',
                  style: TextStyle(
                      color: AppTheme.primaryBrand.withValues(alpha: 0.7),
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodLogEntryRow(dynamic entry, String diaryDate) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.foodName as String,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(entry.grams as double).toStringAsFixed(0)}g · P${(entry.protein as double).toStringAsFixed(0)}g  C${(entry.carbs as double).toStringAsFixed(0)}g  F${(entry.fats as double).toStringAsFixed(0)}g',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${(entry.calories as double).toStringAsFixed(0)} kcal',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final ok = await ref
                  .read(foodLogProvider.notifier)
                  .deleteLog(entry.id as String, diaryDate);
              if (!ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed to remove entry'),
                    backgroundColor: Colors.red));
              }
            },
            child: Icon(Icons.close,
                size: 16, color: Colors.white.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }

  String _capitalizeMealType(String t) =>
      t.isEmpty ? t : t[0] + t.substring(1).toLowerCase();

  Widget _buildSessionMacros(SessionProgressState sessionProgress) {
    final remaining = sessionProgress.remainingCalories;
    final isOnTrack =
        remaining > 0 && remaining < sessionProgress.targetCalories;
    final isOverLimit = remaining < 0;

    final isAIGenerated = ref.watch(dietPlanIsAIGeneratedProvider);
    final assignmentState = ref.watch(trainerAssignmentProvider);
    final String? trainerName = assignmentState is TrainerAssignmentLoaded
        ? assignmentState.assignedTrainer?.fullName
        : null;
    final badge = PlanSourceBadge.fromPlan(
      isAIGenerated: isAIGenerated,
      trainerName: isAIGenerated ? null : trainerName,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Today's Macros",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showShoppingBasket(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_basket_outlined,
                    color: AppTheme.primaryBrand, size: 18),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: isOverLimit
                      ? Colors.redAccent.withValues(alpha: 0.1)
                      : AppTheme.primaryBrand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isOverLimit
                          ? Colors.redAccent.withValues(alpha: 0.2)
                          : AppTheme.primaryBrand.withValues(alpha: 0.2))),
              child: Row(
                children: [
                  Icon(isOverLimit ? Icons.warning_amber : Icons.auto_awesome,
                      color: isOverLimit
                          ? Colors.redAccent
                          : AppTheme.primaryBrand,
                      size: 14),
                  const SizedBox(width: 4),
                  Text(
                      isOverLimit
                          ? "OVER LIMIT"
                          : isOnTrack
                              ? "ON TRACK"
                              : "GET STARTED",
                      style: TextStyle(
                          color: isOverLimit
                              ? Colors.redAccent
                              : AppTheme.primaryBrand,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ],
              ),
            )
          ],
        ),
        if (badge != null) ...[
          const SizedBox(height: 8),
          badge,
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isOverLimit ? "Calories Over" : "Calories Remaining",
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("${remaining.abs()}",
                              style: TextStyle(
                                  color: isOverLimit
                                      ? Colors.redAccent
                                      : Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold)),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6.0, left: 4.0),
                            child: Text("kcal",
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12)),
                    child: Icon(Icons.local_fire_department,
                        color: isOverLimit
                            ? Colors.redAccent
                            : AppTheme.primaryBrand,
                        size: 24),
                  )
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSessionMacroBar(
                      "Protein",
                      sessionProgress.consumedProtein,
                      sessionProgress.targetProtein,
                      AppTheme.primaryBrand),
                  const SizedBox(width: 16),
                  _buildSessionMacroBar("Carbs", sessionProgress.consumedCarbs,
                      sessionProgress.targetCarbs, Colors.blueAccent),
                  const SizedBox(width: 16),
                  _buildSessionMacroBar("Fats", sessionProgress.consumedFats,
                      sessionProgress.targetFats, Colors.greenAccent),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionMacroBar(
      String label, int current, int target, Color color) {
    double progress = target > 0 ? (current / target) : 0.0;
    final isOver = progress > 1.0;
    if (progress > 1.0) progress = 1.0;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              Text("${current}g",
                  style: TextStyle(
                      color: isOver ? Colors.redAccent : color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.white10, borderRadius: BorderRadius.circular(4)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                    color: isOver ? Colors.redAccent : color,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text("Goal: ${target}g",
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSessionMealsHeader(SessionProgressState sessionProgress) {
    final completedMeals = sessionProgress.completedMeals;
    final totalMeals = sessionProgress.totalMeals;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Meals",
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text("$completedMeals/$totalMeals Logged",
            style: TextStyle(
                color: completedMeals == totalMeals
                    ? const Color(0xFF2ECC71)
                    : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMacroChips(MealProgress meal) {
    return Row(
      children: [
        _macroChip('P', '${meal.protein}g', const Color(0xFF3498DB)),
        const SizedBox(width: 6),
        _macroChip('C', '${meal.carbs}g', const Color(0xFFF1C40E)),
        const SizedBox(width: 6),
        _macroChip('F', '${meal.fats}g', const Color(0xFFE67E22)),
      ],
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildInteractiveMealCard(
    MealProgress meal, {
    required bool isTodaySelected,
    required bool isPastDay,
    required bool isFutureDay,
  }) {
    final isDone = meal.isCompleted;
    final isExpanded = _expandedMeals.contains(meal.mealId);
    final isLocked = !isTodaySelected;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isTodaySelected
            ? AppTheme.surfaceDark.withValues(alpha: 0.95)
            : AppTheme.backgroundDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDone
              ? const Color(0xFF2ECC71).withValues(alpha: 0.5)
              : isTodaySelected
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.03),
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: (isDone || isTodaySelected)
            ? [
                BoxShadow(
                  color: isDone
                      ? const Color(0xFF2ECC71).withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Opacity(
        opacity: isTodaySelected ? 1.0 : 0.6,
        child: Column(
          children: [
            // Main row - tap to expand
            GestureDetector(
              onTap: () => _toggleMealExpanded(meal.mealId),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                        border: Border.all(color: Colors.white10),
                        image: meal.imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(meal.imageUrl),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: meal.imageUrl.isEmpty && meal.emoji != null
                          ? Text(meal.emoji!,
                              style: const TextStyle(fontSize: 28))
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(meal.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: isLocked && !isDone
                                            ? Colors.white38
                                            : Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              ),
                              if (isLocked) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPastDay
                                        ? Colors.white10
                                        : AppTheme.primaryBrand
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isPastDay ? "HISTORY" : "FUTURE",
                                    style: TextStyle(
                                      color: isPastDay
                                          ? Colors.white24
                                          : AppTheme.primaryBrand
                                              .withValues(alpha: 0.5),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.white38,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(meal.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 6),
                          _buildMacroChips(meal),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("${meal.calories} kcal",
                        style: TextStyle(
                            color:
                                isDone ? AppTheme.primaryBrand : Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    // Check circle - only this toggles completion
                    GestureDetector(
                      onTap: () {
                        if (!isTodaySelected) {
                          AppNotifications.showError(
                              context, "You can only mark today's meals.");
                          return;
                        }
                        ref
                            .read(sessionProgressProvider.notifier)
                            .toggleMealCompletion(meal.mealId);
                      },
                      child: Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone
                                ? (isTodaySelected
                                    ? const Color(0xFF2ECC71)
                                    : Colors.white24)
                                : Colors.transparent,
                            border: isDone
                                ? null
                                : Border.all(
                                    color: isTodaySelected
                                        ? Colors.white38
                                        : Colors.white10,
                                    width: 2)),
                        child: isDone
                            ? Icon(Icons.check,
                                color: isTodaySelected
                                    ? Colors.black
                                    : Colors.white54,
                                size: 22)
                            : (!isTodaySelected && !isDone
                                ? const Icon(Icons.lock_outline,
                                    color: Colors.white10, size: 16)
                                : null),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded items list + Log button
            if (isExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Food Items",
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                        Text(
                            "P:${meal.protein}g • C:${meal.carbs}g • F:${meal.fats}g",
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (meal.ingredients.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...meal.ingredients.map((item) => _buildMealItemRow(item)),
                    ],
                    if (!ref.watch(dietPlanIsAIGeneratedProvider) &&
                        meal.instructions != null &&
                        meal.instructions!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text("TRAINER NOTES",
                          style: TextStyle(
                              color: Color(0xFFF1C40F),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0)),
                      const SizedBox(height: 4),
                      Text(meal.instructions!,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                              fontStyle: FontStyle.italic)),
                    ],
                    if (isTodaySelected) ...[
                      const SizedBox(height: 12),
                      _buildLogMealButton(meal),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogMealButton(MealProgress meal) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: OutlinedButton.icon(
        onPressed: () => _logMealToDiary(meal),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryBrand,
          side: BorderSide(color: AppTheme.primaryBrand.withValues(alpha: 0.4)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        icon: const Icon(Icons.add_circle_outline, size: 16),
        label: Text(
          'Log this meal  •  ${meal.calories} kcal',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _logMealToDiary(MealProgress meal) async {
    // Map Flutter MealType enum to backend enum string
    String mealTypeStr(MealType t) {
      switch (t) {
        case MealType.breakfast:
          return 'BREAKFAST';
        case MealType.lunch:
          return 'LUNCH';
        case MealType.dinner:
          return 'DINNER';
        case MealType.snack:
          return 'SNACK';
        case MealType.morningSnack:
          return 'SNACK';
        case MealType.afternoonSnack:
          return 'SNACK';
      }
    }

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/food/log', data: {
        'mealType': mealTypeStr(meal.mealType),
        'grams': 100, // standard serving size for plan meals
        'externalFood': {
          'name': meal.name,
          'calories': meal.calories,
          'protein': meal.protein,
          'carbs': meal.carbs,
          'fat': meal.fats,
          'source': 'USER',
        },
      });
      // Award points for completing a meal task.
      await ref.read(pointsProvider.notifier).awardMealLogged();
      final pts = ref.read(pointsProvider).lastAwardedPoints ?? kPointsPerMeal;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${meal.name} logged  +$pts pts'),
          backgroundColor: const Color(0xFF2ECC71),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg =
            e.response?.data?['error']?['message'] ?? 'Failed to log meal';
        AppNotifications.showError(context, msg);
      }
    } catch (_) {
      if (mounted) {
        AppNotifications.showError(context, 'Failed to log meal — try again');
      }
    }
  }

  Widget _buildMealItemRow(MealIngredient item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (item.emoji != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(item.emoji!, style: const TextStyle(fontSize: 16)),
            )
          else
            Container(
              height: 6,
              width: 6,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBrand.withValues(alpha: 0.6),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                if (item.protein > 0 || item.carbs > 0 || item.fats > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "${item.protein}P · ${item.carbs}C · ${item.fats}F",
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(item.portion,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 12),
          if (item.calories > 0)
            SizedBox(
              width: 55,
              child: Text("${item.calories} kcal",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyMealsState(BuildContext context,
      {plan_entity.MonthlyDietPlanEntity? plan, int? activeDay}) {
    String message = "No Meals Planned";
    String subtitle =
        "Tap the AI button below to generate a personalized diet plan instantly.";

    if (plan != null && activeDay != null) {
      final now = DateTime.now();
      final mondayOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
      final targetDate = DateTime(mondayOfThisWeek.year, mondayOfThisWeek.month,
          mondayOfThisWeek.day + activeDay);

      final normalizedTarget =
          DateTime(targetDate.year, targetDate.month, targetDate.day);
      final normalizedStart = DateTime(
          plan.startDate.year, plan.startDate.month, plan.startDate.day);
      final todayWeekday = now.weekday - 1;

      if (normalizedTarget.isBefore(normalizedStart)) {
        message = activeDay < todayWeekday
            ? "No record for this day"
            : "Plan starts soon";
        subtitle = activeDay < todayWeekday
            ? "This day was before your current diet plan activated."
            : "Your new personalized nutrition plan will begin on ${_formatShortDate(plan.startDate)}.";
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.primaryBrand.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBrand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_menu,
                color: AppTheme.primaryBrand, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  void _showShoppingBasket() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (modalContext) => const _ShoppingBasketModal(),
    );
  }
}

class _AIDietAssistantModal extends ConsumerWidget {
  final VoidCallback onLaunchOnboarding;
  final VoidCallback onShowSwapMeal;

  const _AIDietAssistantModal({
    required this.onLaunchOnboarding,
    required this.onShowSwapMeal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppTheme.modalBackground,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.modalRadius)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.modalRadius)),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppTheme.modalBlur, sigmaY: AppTheme.modalBlur),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: AppTheme.modalHandleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildHeader(context),
              Expanded(
                child: _buildOptions(context, ref),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Diet Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Refine your plan with AI intelligence',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        _buildAIOption(
          icon: Icons.calendar_month,
          title: "Generate 30-Day Plan",
          subtitle: "AI creates personalized monthly meal plan",
          onTap: () {
            Navigator.pop(context);
            onLaunchOnboarding();
          },
        ),
        _buildAIOption(
          icon: Icons.swap_horiz,
          title: "Swap This Meal",
          subtitle: "Get alternative meal suggestions",
          onTap: () {
            Navigator.pop(context);
            onShowSwapMeal();
          },
        ),
        _buildAIOption(
          icon: Icons.chat_bubble_outline,
          title: "Ask AI",
          subtitle: "Chat about nutrition and diet advice",
          onTap: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildAIOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryBrand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryBrand, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
      ),
    );
  }

  Widget _buildFooter() {
    return const SizedBox(height: 24);
  }
}

class _ShoppingBasketModal extends ConsumerWidget {
  const _ShoppingBasketModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(aggregatedShoppingIngredientsProvider);
    final daysRange = ref.watch(shoppingDaysRangeProvider);
    final checkedItems = ref.watch(checkedShoppingItemsProvider);
    final daysLeftData = ref.watch(dietDaysLeftProvider);

    final int daysLeft = daysLeftData['left'] as int;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.modalBackground,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.modalRadius)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.modalRadius)),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppTheme.modalBlur, sigmaY: AppTheme.modalBlur),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: AppTheme.modalHandleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Smart Basket",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("$daysLeft Days Left in Plan",
                              style: const TextStyle(
                                  color: AppTheme.primaryBrand,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Shopping Window Slider (Dynamic max based on days left)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Shopping window",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                        Text("$daysRange days",
                            style: const TextStyle(
                                color: AppTheme.primaryBrand,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.primaryBrand,
                        inactiveTrackColor: Colors.white10,
                        thumbColor: AppTheme.primaryBrand,
                        overlayColor:
                            AppTheme.primaryBrand.withValues(alpha: 0.2),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: daysRange
                            .toDouble()
                            .clamp(1.0, daysLeft.toDouble().clamp(1.0, 31.0)),
                        min: 1,
                        max: daysLeft.toDouble().clamp(1.0, 31.0),
                        divisions: daysLeft.clamp(1, 31),
                        onChanged: (val) {
                          ref
                              .read(shoppingDaysRangeProvider.notifier)
                              .update(val.toInt());
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (ingredients.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.no_food_outlined,
                            color: Colors.white24, size: 48),
                        SizedBox(height: 16),
                        Text("No ingredients found for this range",
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    children: [
                      // TO BUY SECTION
                      if (ingredients.any((i) => i.amount != "0")) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12, top: 8),
                          child: Text("NEED TO PURCHASE",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              )),
                        ),
                        ...ingredients.where((i) => i.amount != "0").map((ing) {
                          final itemKey =
                              "${ing.name.toLowerCase()}_${ing.unit.toLowerCase()}";
                          final isChecked = checkedItems[itemKey] ?? false;
                          return _buildIngredientCard(
                              context, ref, ing, isChecked, false);
                        }),
                      ],

                      // STOCKED SECTION
                      if (ingredients.any((i) => i.amount == "0")) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12, top: 24),
                          child: Text("STOCKED & READY",
                              style: TextStyle(
                                color: Color(0xFF2ECC71),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              )),
                        ),
                        ...ingredients.where((i) => i.amount == "0").map((ing) {
                          return _buildIngredientCard(
                              context, ref, ing, true, true);
                        }),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              // Footer Total
              if (ingredients.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    border: Border(
                        top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${ingredients.length} total items",
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                      Text(
                          "${checkedItems.values.where((v) => v).length} in basket",
                          style: const TextStyle(
                              color: AppTheme.primaryBrand,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              // Purchasing Actions
              if (ingredients.any((i) => i.amount != "0"))
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: checkedItems.values.any((checked) => checked)
                          ? () {
                              // Move items to pantry
                              final currentPantry = Map<String, double>.from(
                                  ref.read(virtualPantryProvider));
                              for (final ing in ingredients) {
                                final itemKey =
                                    "${ing.name.toLowerCase()}_${ing.unit.toLowerCase()}";
                                final isChecked =
                                    checkedItems[itemKey] ?? false;

                                // ONLY move items that are actually checked in the UI
                                if (ing.amount != "0" && isChecked) {
                                  final nameKey = ing.name.toLowerCase();
                                  final qty =
                                      double.tryParse(ing.amount) ?? 0.0;
                                  currentPantry[nameKey] =
                                      (currentPantry[nameKey] ?? 0.0) + qty;
                                }
                              }
                              ref
                                  .read(virtualPantryProvider.notifier)
                                  .updatePantry(currentPantry);

                              // Clear checks
                              ref
                                  .read(checkedShoppingItemsProvider.notifier)
                                  .clear();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      "Added items to your Virtual Pantry!"),
                                  backgroundColor: const Color(0xFF2ECC71)
                                      .withValues(alpha: 0.9),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBrand,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 20),
                          SizedBox(width: 8),
                          Text("Confirm Purchase (Add to Pantry)",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientCard(BuildContext context, WidgetRef ref,
      plan_entity.IngredientEntity ing, bool isChecked, bool isInPantry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isInPantry
            ? const Color(0xFF2ECC71).withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isChecked
                ? (isInPantry ? const Color(0xFF2ECC71) : AppTheme.primaryBrand)
                    .withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Opacity(
        opacity: isInPantry ? 0.6 : 1.0,
        child: CheckboxListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          value: isChecked,
          onChanged: isInPantry
              ? null
              : (val) {
                  final itemKey =
                      "${ing.name.trim().toLowerCase()}_${ing.unit.trim().toLowerCase()}";
                  ref
                      .read(checkedShoppingItemsProvider.notifier)
                      .toggle(itemKey, val ?? false);
                },
          title: Text(ing.name,
              style: TextStyle(
                color:
                    (isChecked || isInPantry) ? Colors.white38 : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                decoration: (isChecked || isInPantry)
                    ? TextDecoration.lineThrough
                    : null,
              )),
          subtitle: Row(
            children: [
              Text(
                  isInPantry
                      ? "ALREADY IN PANTRY"
                      : "${ing.amount} ${ing.unit}",
                  style: TextStyle(
                    color: isInPantry
                        ? const Color(0xFF2ECC71)
                        : AppTheme.primaryBrand,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  )),
              if (isInPantry) ...[
                const SizedBox(width: 4),
                const Icon(Icons.inventory_2_outlined,
                    size: 10, color: Color(0xFF2ECC71)),
              ],
            ],
          ),
          secondary: Text(
            FoodEmojiRegistry.getEmoji(ing.name),
            style: const TextStyle(fontSize: 24),
          ),
          activeColor:
              isInPantry ? const Color(0xFF2ECC71) : AppTheme.primaryBrand,
          checkColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
