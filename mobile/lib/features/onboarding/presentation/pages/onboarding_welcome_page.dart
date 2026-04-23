import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../design_system/tokens/app_tokens.dart';
import '../../../../design_system/components/glass_card.dart';
import '../../../../design_system/components/glass_onboarding_background.dart';

class OnboardingWelcomePage extends StatelessWidget {
  final VoidCallback onReady;

  const OnboardingWelcomePage({super.key, required this.onReady});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final h = size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassOnboardingBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.08),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: h * 0.04),
                    // Coach avatar with high-end glass effect
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: w * 0.45,
                          height: w * 0.45,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTokens.colorBrand.withValues(alpha: 0.3),
                                AppTokens.colorBrand.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1.1, 1.1),
                              duration: 3.seconds,
                              curve: Curves.easeInOut,
                            ),
                        GlassCard(
                          padding: const EdgeInsets.all(AppTokens.space24),
                          borderRadius: BorderRadius.circular(w * 0.25),
                          child: Image.asset(
                            'assets/images/app_logo_transparent.png',
                            width: w * 0.20,
                            height: w * 0.20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: 800.ms)
                        .scale(begin: const Offset(0.7, 0.7), duration: 800.ms, curve: Curves.easeOutBack),
                    
                    SizedBox(height: h * 0.05),
                    
                    // Welcome Content in Glass
                    GlassCard(
                      child: Column(
                        children: [
                          Text(
                            'Amirani AI',
                            style: AppTokens.textDisplayLg.copyWith(
                              fontSize: 32,
                              letterSpacing: -1,
                            ),
                          ),
                          SizedBox(height: h * 0.01),
                          Text(
                            "I'm your personal AI coach. Let's build your perfect transformation plan together.",
                            textAlign: TextAlign.center,
                            style: AppTokens.textBodyLg.copyWith(
                              color: AppTokens.colorTextSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate(delay: 300.ms)
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),

                    SizedBox(height: h * 0.04),
                    
                    // Time estimate with subtle blur
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt, size: 16, color: AppTokens.colorBrand),
                              const SizedBox(width: 8),
                              Text(
                                'Setup takes 60 seconds',
                                style: AppTokens.textLabelSm.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                        .animate(delay: 500.ms)
                        .fadeIn(duration: 400.ms),

                    SizedBox(height: h * 0.06),
                    
                    // Premium Action Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTokens.radius16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTokens.colorBrand.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: onReady,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.colorBrand,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTokens.radius16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "START TRANSFORMATION",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    )
                        .animate(delay: 800.ms)
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: 0.5, end: 0, duration: 600.ms, curve: Curves.easeOutQuart),
                    
                    SizedBox(height: h * 0.04),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
