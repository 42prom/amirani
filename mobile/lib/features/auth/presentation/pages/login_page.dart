import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../../core/config/service_availability.dart';
import 'package:amirani_app/design_system/tokens/app_tokens.dart';

// ─── Country data ─────────────────────────────────────────────────────────────

class _Country {
  final String code;
  final String name;
  final String flag;
  const _Country(this.code, this.name, this.flag);
}

// Georgia first, then globally popular, then alphabetical.
const List<_Country> _kCountries = [
  _Country('GE', 'Georgia', '🇬🇪'),
  _Country('US', 'United States', '🇺🇸'),
  _Country('GB', 'United Kingdom', '🇬🇧'),
  _Country('DE', 'Germany', '🇩🇪'),
  _Country('FR', 'France', '🇫🇷'),
  _Country('TR', 'Turkey', '🇹🇷'),
  _Country('RU', 'Russia', '🇷🇺'),
  _Country('UA', 'Ukraine', '🇺🇦'),
  _Country('AM', 'Armenia', '🇦🇲'),
  _Country('AZ', 'Azerbaijan', '🇦🇿'),
  _Country('AE', 'United Arab Emirates', '🇦🇪'),
  _Country('AU', 'Australia', '🇦🇺'),
  _Country('AT', 'Austria', '🇦🇹'),
  _Country('BE', 'Belgium', '🇧🇪'),
  _Country('BR', 'Brazil', '🇧🇷'),
  _Country('CA', 'Canada', '🇨🇦'),
  _Country('CN', 'China', '🇨🇳'),
  _Country('CZ', 'Czech Republic', '🇨🇿'),
  _Country('DK', 'Denmark', '🇩🇰'),
  _Country('EG', 'Egypt', '🇪🇬'),
  _Country('ES', 'Spain', '🇪🇸'),
  _Country('FI', 'Finland', '🇫🇮'),
  _Country('GR', 'Greece', '🇬🇷'),
  _Country('HU', 'Hungary', '🇭🇺'),
  _Country('ID', 'Indonesia', '🇮🇩'),
  _Country('IL', 'Israel', '🇮🇱'),
  _Country('IN', 'India', '🇮🇳'),
  _Country('IR', 'Iran', '🇮🇷'),
  _Country('IT', 'Italy', '🇮🇹'),
  _Country('JP', 'Japan', '🇯🇵'),
  _Country('KR', 'South Korea', '🇰🇷'),
  _Country('KZ', 'Kazakhstan', '🇰🇿'),
  _Country('LT', 'Lithuania', '🇱🇹'),
  _Country('LV', 'Latvia', '🇱🇻'),
  _Country('MD', 'Moldova', '🇲🇩'),
  _Country('MX', 'Mexico', '🇲🇽'),
  _Country('NL', 'Netherlands', '🇳🇱'),
  _Country('NO', 'Norway', '🇳🇴'),
  _Country('PL', 'Poland', '🇵🇱'),
  _Country('PT', 'Portugal', '🇵🇹'),
  _Country('RO', 'Romania', '🇷🇴'),
  _Country('SA', 'Saudi Arabia', '🇸🇦'),
  _Country('SE', 'Sweden', '🇸🇪'),
  _Country('SG', 'Singapore', '🇸🇬'),
  _Country('SK', 'Slovakia', '🇸🇰'),
  _Country('TH', 'Thailand', '🇹🇭'),
  _Country('TN', 'Tunisia', '🇹🇳'),
  _Country('UZ', 'Uzbekistan', '🇺🇿'),
  _Country('ZA', 'South Africa', '🇿🇦'),
];

// ─── Login page ───────────────────────────────────────────────────────────────

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  _Country? _selectedCountry;
  String? _countryError;

  /// Opens a searchable bottom sheet and returns the picked country.
  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<_Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CountryPickerSheet(),
    );

    if (picked != null) {
      setState(() {
        _selectedCountry = picked;
        _countryError = null;
      });
    }
  }

  /// Validates country selection before starting OAuth. Returns true if valid.
  bool _validateCountry() {
    if (_selectedCountry == null) {
      setState(() => _countryError = 'Please select your country to continue');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;
    final errorMessage = authState is AuthError ? authState.message : null;

    return Scaffold(
      backgroundColor: AppTokens.colorBgPrimary,
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

                  const SizedBox(height: 40),

                  // ── Country selector ──────────────────────────────────
                  _CountrySelector(
                    selected: _selectedCountry,
                    error: _countryError,
                    onTap: isLoading ? null : _pickCountry,
                  ),

                  const SizedBox(height: 20),

                  // ── Auth error message ────────────────────────────────
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

                  // ── Google button ──────────────────────────────────────
                  if (ServiceAvailability.googleAuth) ...[
                    _SocialButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              if (!_validateCountry()) return;
                              ref
                                  .read(authNotifierProvider.notifier)
                                  .loginWithGoogle(_selectedCountry!.code);
                            },
                      isLoading: isLoading,
                      icon: _GoogleIcon(),
                      label: 'Continue with Google',
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1F1F1F),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Apple button ───────────────────────────────────────
                  if (!kIsWeb && (Platform.isIOS || Platform.isMacOS) &&
                      ServiceAvailability.appleAuth)
                    _SocialButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              if (!_validateCountry()) return;
                              ref
                                  .read(authNotifierProvider.notifier)
                                  .loginWithApple(_selectedCountry!.code);
                            },
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
                          color: AppTokens.colorBrand,
                          onPressed: isLoading
                              ? null
                              : () => ref
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

// ─── Country selector widget ─────────────────────────────────────────────────

class _CountrySelector extends StatelessWidget {
  final _Country? selected;
  final String? error;
  final VoidCallback? onTap;

  const _CountrySelector({this.selected, this.error, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasError
                    ? Colors.redAccent.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                if (selected != null) ...[
                  Text(selected!.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selected!.name,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      'Select your country',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 15,
                      ),
                    ),
                  ),
                Icon(Icons.expand_more,
                    color: Colors.white.withValues(alpha: 0.4), size: 20),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 13),
              const SizedBox(width: 6),
              Text(
                error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Country picker bottom sheet ─────────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<_Country> _filtered = _kCountries;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _kCountries
          : _kCountries
              .where((c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.code.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          // ── Handle ────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ─────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Select your country',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Search field ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search country…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                prefixIcon: Icon(Icons.search,
                    color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No country found',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              Text(c.flag,
                                  style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                              ),
                              Text(
                                c.code,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Social button ────────────────────────────────────────────────────────────

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
        height: 52,
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

// ─── Google coloured G icon ───────────────────────────────────────────────────

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
    final double r = (size.width - strokeWidth) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect rect = Rect.fromCircle(center: center, radius: r);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    canvas.drawArc(rect, -2.35, 1.35, false, paint..color = const Color(0xFFEA4335));
    canvas.drawArc(rect, 2.35, 1.58, false, paint..color = const Color(0xFFFBBC05));
    canvas.drawArc(rect, 0.75, 1.6, false, paint..color = const Color(0xFF34A853));
    canvas.drawArc(rect, -0.6, 1.35, false, paint..color = const Color(0xFF4285F4));

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final double barHeight = strokeWidth;
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - barHeight / 2, r + strokeWidth / 2, barHeight),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Dev-only button ──────────────────────────────────────────────────────────

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
