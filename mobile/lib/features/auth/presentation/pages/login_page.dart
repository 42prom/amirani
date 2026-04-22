import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../../core/config/service_availability.dart';
import 'package:amirani_app/theme/app_theme.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;
    final errorMessage = authState is AuthError ? authState.message : null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo ───────────────────────────────────────────────
                  Image.asset(
                    'assets/images/app_logo_transparent.png',
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Amirani',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your AI-Powered Gym Companion',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 56),

                  // ── Error message ─────────────────────────────────────
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Google button (only when Firebase is configured) ───
                  if (ServiceAvailability.googleAuth) ...[
                    _SocialButton(
                      onPressed: isLoading
                          ? null
                          : () => ref
                              .read(authNotifierProvider.notifier)
                              .loginWithGoogle(),
                      isLoading: isLoading,
                      icon: _GoogleIcon(),
                      label: 'Continue with Google',
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1F1F1F),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Apple button (iOS/macOS only, when configured) ─────
                  if (!kIsWeb && (Platform.isIOS || Platform.isMacOS) &&
                      ServiceAvailability.appleAuth)
                    _SocialButton(
                      onPressed: isLoading
                          ? null
                          : () => ref
                              .read(authNotifierProvider.notifier)
                              .loginWithApple(),
                      isLoading: isLoading,
                      icon: const Icon(Icons.apple,
                          color: Colors.white, size: 22),
                      label: 'Continue with Apple',
                      backgroundColor: const Color(0xFF1C1C1E),
                      foregroundColor: Colors.white,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),

                  const SizedBox(height: 40),

                  // ── Terms ─────────────────────────────────────────────
                  Text(
                    'By continuing you agree to our Terms of Service\nand Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),

                  // ── DEV ONLY quick login ──────────────────────────────
                  if (const bool.fromEnvironment('dart.vm.product') == false) ...[
                    const SizedBox(height: 40),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    const Text(
                      'DEV ONLY',
                      style: TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DevButton(
                          label: 'Member',
                          color: AppTheme.primaryBrand,
                          onPressed: isLoading ? null : () => ref
                              .read(authNotifierProvider.notifier)
                              .login('mobile@amirani.dev', 'MobileUser123!'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Social button ─────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final BoxBorder? border;

  const _SocialButton({
    required this.onPressed,
    required this.isLoading,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 52, // Explicit height for better consistency
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: border,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Google coloured G icon ────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = size.width * 0.22;
    // Reduce radius to keep stroke entirely inside the box
    final double r = (size.width - strokeWidth) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect rect = Rect.fromCircle(center: center, radius: r);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    // Red (Top)
    canvas.drawArc(rect, -2.35, 1.35, false, paint..color = const Color(0xFFEA4335));
    // Yellow (Left)
    canvas.drawArc(rect, 2.35, 1.58, false, paint..color = const Color(0xFFFBBC05));
    // Green (Bottom)
    canvas.drawArc(rect, 0.75, 1.6, false, paint..color = const Color(0xFF34A853));
    // Blue (Right part)
    canvas.drawArc(rect, -0.6, 1.35, false, paint..color = const Color(0xFF4285F4));

    // Blue Bar (The horizontal part)
    final barPaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    final double barHeight = strokeWidth;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - barHeight / 2,
        r + strokeWidth / 2,
        barHeight,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _DevButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _DevButton({
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
