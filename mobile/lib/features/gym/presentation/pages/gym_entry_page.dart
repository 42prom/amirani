import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import '../../../../theme/app_theme.dart';
import '../providers/gym_access_provider.dart';
import '../providers/membership_provider.dart';

// ─── Page ─────────────────────────────────────────────────────────────────────

class GymEntryPage extends ConsumerStatefulWidget {
  const GymEntryPage({super.key});

  @override
  ConsumerState<GymEntryPage> createState() => _GymEntryPageState();
}

class _GymEntryPageState extends ConsumerState<GymEntryPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  late final MobileScannerController _scanner;
  late final AnimationController _scanLineCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scanLineAnim;
  late final Animation<double> _pulseAnim;

  bool _processed = false;
  String? _errorMessage;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: [BarcodeFormat.qrCode],
      autoStart: true,
    );
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // The OS permission dialog is a separate Android Activity overlay which
  // triggers AppLifecycleState.paused → .resumed.  Stopping on paused and
  // restarting on resumed forces CameraX to fully re-initialise its capture
  // session after the dialog closes.  Without this, CameraX is ACTIVE but the
  // Flutter Texture buffer queue overflows (10 buffers) because frames are
  // produced before the Texture render object is ready → black screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _scanner.stop();
      case AppLifecycleState.resumed:
        if (!_processed) _scanner.start();
      default:
        break;
    }
  }

  // ─── QR detection ───────────────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_processed) return;
    if (capture.barcodes.isEmpty) return;
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _processed = true;
    HapticFeedback.mediumImpact();
    _scanner.stop();
    _parseAndCheckIn(rawValue);
  }

  void _parseAndCheckIn(String rawValue) {
    Uri? uri;
    try {
      uri = Uri.parse(rawValue);
    } catch (_) {}

    // ── Gym registration QR: amirani://register?gymId=X&code=Y ────────────────
    if (uri != null && uri.scheme == 'amirani' && uri.host == 'register') {
      final gymId = uri.queryParameters['gymId'] ?? '';
      final code  = uri.queryParameters['code']  ?? '';
      if (gymId.isNotEmpty && code.isNotEmpty) {
        // Zero-Friction: If already a member, go straight to Gym tab
        final membershipState = ref.read(membershipProvider);
        bool isAlreadyMember = false;
        if (membershipState is MembershipLoaded) {
          isAlreadyMember = membershipState.memberships.any((m) => m.gymId == gymId && m.isActive);
        }

        Navigator.of(context, rootNavigator: true).pop();
        if (isAlreadyMember) {
          context.go('/gym');
        } else {
          context.go('/gym-register?gymId=$gymId&code=$code');
        }
        return;
      }
    }

    // ── Daily check-in QR: amirani://checkin?gymId=X&token=Y ─────────────────
    if (uri != null && uri.scheme == 'amirani' && uri.host == 'checkin') {
      final gymId = uri.queryParameters['gymId'] ?? '';
      final token = uri.queryParameters['token'] ?? '';
      if (gymId.isNotEmpty && token.isNotEmpty) {
        _doCheckIn(gymId, token);
        return;
      }
    }

    // ── Unrecognised QR ───────────────────────────────────────────────────────
    setState(() {
      _errorMessage =
          'This QR code is not recognised. Please scan the official Amirani QR code at the gym entrance.';
      _processed = false;
    });
    _scanner.start();
  }

  Future<void> _doCheckIn(String gymId, String token) async {
    try {
      await ref
          .read(gymAccessProvider.notifier)
          .performQrCheckIn(gymId, token);
      if (!mounted) return;
      final accessState = ref.read(gymAccessProvider);
      if (accessState is GymAccessAdmitted) {
        Navigator.of(context, rootNavigator: true).pop(true);
      } else if (accessState is GymAccessDenied) {
        setState(() {
          _errorMessage = accessState.reason;
          _processed = false;
        });
        _scanner.start();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Network error — please check your connection and try again.';
        _processed = false;
      });
      _scanner.start();
    }
  }

  void _retry() => setState(() {
        _errorMessage = null;
        _processed = false;
      });

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accessState = ref.watch(gymAccessProvider);
    final isValidating = accessState is GymAccessValidating;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera layer ──────────────────────────────────────────────────
          Positioned.fill(
            child: MobileScanner(
              controller: _scanner,
              fit: BoxFit.cover,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) => _buildCameraError(error),
            ),
          ),

          // ── Radial vignette ───────────────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.75,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),

          // ── Scanning viewport (Center) ────────────────────────────────────
          Positioned.fill(child: _buildScanViewport()),

          // ── Top bar (Safe Area) ───────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildTopBar()),
          ),

          // ── Bottom info panel (Safe Area) ─────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _buildBottomPanel(isValidating),
            ),
          ),

          // ── Validating overlay ────────────────────────────────────────────
          if (isValidating) _buildValidatingOverlay(),
        ],
      ),
    );
  }

  // ── Camera permission / error overlay ────────────────────────────────────

  Widget _buildCameraError(MobileScannerException error) {
    final bool isPermDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 88,
            width: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: 0.1),
              border: Border.all(
                  color: Colors.red.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Icon(Icons.no_photography,
                color: Colors.red.withValues(alpha: 0.8), size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            isPermDenied ? 'Camera Permission Denied' : 'Camera Error',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              isPermDenied
                  ? 'Enable camera access in Settings to use the QR scanner.'
                  : 'Unable to start the camera. Please try again.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed:
                isPermDenied ? openAppSettings : () => _scanner.start(),
            icon: Icon(
                isPermDenied ? Icons.settings_outlined : Icons.refresh,
                size: 18),
            label: Text(
                isPermDenied ? 'Open Settings' : 'Try Again',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBrand,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ──────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
            child: _iconButton(Icons.arrow_back),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _scanner.toggleTorch(),
            child: _iconButton(Icons.flashlight_on),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildScanViewport() {
    return Center(
      child: ScaleTransition(
        scale: _pulseAnim,
        child: SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            children: [
              _Corner(alignment: Alignment.topLeft,
                  corners: const [true, false, false, true]),
              _Corner(alignment: Alignment.topRight,
                  corners: const [true, true, false, false]),
              _Corner(alignment: Alignment.bottomLeft,
                  corners: const [false, false, true, true]),
              _Corner(alignment: Alignment.bottomRight,
                  corners: const [false, true, true, false]),
              AnimatedBuilder(
                animation: _scanLineAnim,
                builder: (_, __) => Positioned(
                  left: 12,
                  right: 12,
                  top: 12 + (_scanLineAnim.value * 236),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        AppTheme.primaryBrand.withValues(alpha: 0.8),
                        AppTheme.primaryBrand,
                        AppTheme.primaryBrand.withValues(alpha: 0.8),
                        Colors.transparent,
                      ]),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBrand.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
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

  Widget _buildBottomPanel(bool isValidating) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.92),
            Colors.black,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              height: 28,
              width: 28,
              decoration: const BoxDecoration(
                  color: AppTheme.primaryBrand, shape: BoxShape.circle),
              child: const Icon(Icons.fitness_center,
                  color: Colors.black, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('AMIRANI',
                style: TextStyle(
                  color: AppTheme.primaryBrand,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                )),
          ]),
          const SizedBox(height: 20),
          const Text(
            'Scan to Enter',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (_errorMessage != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _retry,
              child: const Text('Try Again',
                  style: TextStyle(
                      color: AppTheme.primaryBrand,
                      fontWeight: FontWeight.bold)),
            ),
          ] else
            Text(
              'Hold your phone up to the QR code\nat the gym entrance',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildValidatingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.65),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
                color: AppTheme.primaryBrand, strokeWidth: 3),
            const SizedBox(height: 20),
            Text(
              'Verifying access…',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Corner bracket decoration ─────────────────────────────────────────────────

class _Corner extends StatelessWidget {
  final Alignment alignment;
  final List<bool> corners; // [top, right, bottom, left]

  const _Corner({required this.alignment, required this.corners});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 28,
        height: 28,
        child: CustomPaint(painter: _CornerPainter(corners, 3.0)),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final List<bool> sides;
  final double thickness;
  const _CornerPainter(this.sides, this.thickness);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryBrand
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    if (sides[0]) canvas.drawLine(Offset.zero, Offset(w, 0), paint);
    if (sides[1]) canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
    if (sides[2]) canvas.drawLine(Offset(0, h), Offset(w, h), paint);
    if (sides[3]) canvas.drawLine(Offset.zero, Offset(0, h), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
