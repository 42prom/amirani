import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/utils/error_messages.dart';
import '../../domain/entities/subscription_plan_entity.dart';
import '../../../gym/presentation/providers/membership_provider.dart';
import '../../../../core/services/payment/stripe_service.dart';

abstract class MembershipPlansState {}

class MembershipPlansInitial extends MembershipPlansState {}
class MembershipPlansLoading extends MembershipPlansState {}
class MembershipPlansLoaded  extends MembershipPlansState {
  final List<SubscriptionPlanEntity> plans;
  MembershipPlansLoaded(this.plans);
}
class MembershipPlansError extends MembershipPlansState {
  final String message;
  MembershipPlansError(this.message);
}

class MembershipPlansNotifier extends StateNotifier<MembershipPlansState> {
  final Ref _ref;

  MembershipPlansNotifier(this._ref) : super(MembershipPlansInitial());

  Future<void> fetchPlans(String gymId) async {
    state = MembershipPlansLoading();
    try {
      final response = await _ref.read(dioProvider).get('/memberships/gyms/$gymId/subscription-plans');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      final plans = data.map((j) => SubscriptionPlanEntity.fromJson(j as Map<String, dynamic>)).toList();
      state = MembershipPlansLoaded(plans);
    } catch (e) {
      state = MembershipPlansError(ErrorMessages.from(e, fallback: 'Failed to load plans'));
    }
  }

  /// Initiate purchase flow for a plan
  Future<String?> purchasePlan({
    required String gymId,
    required String planId,
  }) async {
    try {
      // 1. Get Payment Intent and Ephemeral Key from backend
      // In Step 2.3.1, we implemented purchaseSubscription which returns these.
      final response = await _ref.read(dioProvider).post(
        '/payments/subscribe',
        data: {
          'gymId': gymId,
          'planId': planId,
          'autoRenew': true,
        },
      );

      final data = response.data['data'];
      final clientSecret = data['paymentIntentClientSecret'] as String;
      final customerId = data['customerId'] as String;
      final ephemeralKey = data['ephemeralKeySecret'] as String;

      // 2. Present Stripe Payment Sheet
      await StripeService.presentPaymentSheet(
        paymentIntentClientSecret: clientSecret,
        customerId: customerId,
        ephemeralKeySecret: ephemeralKey,
      );

      // 3. Refresh memberships on success
      await _ref.read(membershipProvider.notifier).fetch();
      
      return null; // Success
    } catch (e) {
      return ErrorMessages.from(e, fallback: 'Payment failed');
    }
  }
}

final membershipPlansProvider = StateNotifierProvider<MembershipPlansNotifier, MembershipPlansState>((ref) {
  return MembershipPlansNotifier(ref);
});

final membershipPlansFamily = StateNotifierProvider.family<MembershipPlansNotifier, MembershipPlansState, String>((ref, gymId) {
  final notifier = MembershipPlansNotifier(ref);
  notifier.fetchPlans(gymId);
  return notifier;
});
