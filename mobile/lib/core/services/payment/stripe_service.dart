import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StripeService {
  static bool _isInitialized = false;

  /// Initialize the Stripe SDK
  static void init() {
    if (_isInitialized) return;

    final publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? 'pk_test_placeholder';
    Stripe.publishableKey = publishableKey;
    Stripe.merchantIdentifier = 'merchant.com.amirani.app'; // For Apple Pay
    
    _isInitialized = true;
  }

  /// Present the payment sheet to the user
  static Future<void> presentPaymentSheet({
    required String paymentIntentClientSecret,
    required String customerId,
    required String ephemeralKeySecret,
    String? merchantDisplayName,
  }) async {
    // Ensure initialized
    init();

    // 1. Initialize Payment Sheet
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: paymentIntentClientSecret,
        customerEphemeralKeySecret: ephemeralKeySecret,
        customerId: customerId,
        merchantDisplayName: merchantDisplayName ?? 'Amirani Gym',
        style: ThemeMode.dark, // Keep consistent with app theme
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(
            primary: Colors.amber, // Pulse Gold
            background: Color(0xFF121212),
            componentBackground: Color(0xFF1E1E1E),
            placeholderText: Colors.grey,
          ),
          shapes: PaymentSheetShape(
            borderRadius: 12,
          ),
        ),
      ),
    );

    // 2. Present Payment Sheet
    await Stripe.instance.presentPaymentSheet();
  }
}
