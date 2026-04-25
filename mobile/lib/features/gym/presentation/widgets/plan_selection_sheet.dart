import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';
import '../providers/membership_plans_provider.dart';
import '../../../../core/utils/app_notifications.dart';

class PlanSelectionSheet extends ConsumerWidget {
  final String gymId;
  final String gymName;

  const PlanSelectionSheet({
    super.key,
    required this.gymId,
    required this.gymName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansState = ref.watch(membershipPlansFamily(gymId));

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTokens.colorBgPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose a Plan',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Join $gymName to unlock all features',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Content
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: _buildPlansContent(context, ref, plansState),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPlansContent(BuildContext context, WidgetRef ref, MembershipPlansState state) {
    if (state is MembershipPlansLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: AppTokens.colorBrand),
        ),
      );
    }

    if (state is MembershipPlansError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.read(membershipPlansFamily(gymId).notifier).fetchPlans(gymId),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is MembershipPlansLoaded) {
      if (state.plans.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(48.0),
            child: Text('No plans available for this gym.', style: TextStyle(color: Colors.white54)),
          ),
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: state.plans.length,
        itemBuilder: (context, index) {
          final plan = state.plans[index];
          return _buildPlanCard(context, ref, plan)
              .animate()
              .fadeIn(delay: (index * 100).ms)
              .slideY(begin: 0.1, end: 0);
        },
      );
    }

    return const SizedBox();
  }

  Widget _buildPlanCard(BuildContext context, WidgetRef ref, dynamic plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTokens.colorBgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handlePurchase(context, ref, plan),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (plan.durationUnit == 'years') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTokens.colorBrand.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'BEST VALUE',
                                style: TextStyle(
                                  color: AppTokens.colorBrand,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.formattedDuration,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...plan.features.take(2).map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check, color: AppTokens.colorBrand, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              f,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${plan.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'one-time',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePurchase(BuildContext context, WidgetRef ref, dynamic plan) async {
    AppNotifications.showInfo(context, 'Preparing checkout...');
    
    final error = await ref.read(membershipPlansFamily(gymId).notifier).purchasePlan(
      gymId: gymId,
      planId: plan.id,
    );

    if (context.mounted) {
      Navigator.pop(context); // Close loading/sheet
      
      if (error != null) {
        AppNotifications.showError(context, error);
      } else {
        AppNotifications.showSuccess(context, 'Welcome to the gym!');
      }
    }
  }
}
