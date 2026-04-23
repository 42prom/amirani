import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:amirani_app/theme/app_theme.dart';
import '../providers/gym_access_provider.dart';
import '../providers/membership_provider.dart';
import '../providers/nfc_key_provider.dart';
import '../../../../core/services/nfc_hce_service.dart';
import 'package:amirani_app/core/widgets/premium_state_card.dart';

// ─── Page ─────────────────────────────────────────────────────────────────────

class GymEntryPage extends ConsumerStatefulWidget {
  const GymEntryPage({super.key});

  @override
  ConsumerState<GymEntryPage> createState() => _GymEntryPageState();
}

class _GymEntryPageState extends ConsumerState<GymEntryPage> with WidgetsBindingObserver {
  late final MobileScannerController _scanner;
  bool _processed = false;
  String? _errorMessage;

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    super.dispose();
  }

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

    if (uri != null && uri.scheme == 'amirani' && uri.host == 'register') {
      final gymId = uri.queryParameters['gymId'] ?? '';
      final code  = uri.queryParameters['code']  ?? '';
      if (gymId.isNotEmpty && code.isNotEmpty) {
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

    if (uri != null && uri.scheme == 'amirani' && uri.host == 'checkin') {
      final gymId = uri.queryParameters['gymId'] ?? '';
      final token = uri.queryParameters['token'] ?? '';
      if (gymId.isNotEmpty && token.isNotEmpty) {
        _doCheckIn(gymId, token);
        return;
      }
    }

    setState(() {
      _errorMessage = 'This QR code is not recognised. Please scan the official Amirani QR code.';
      _processed = false;
    });
    _scanner.start();
  }

  Future<void> _doCheckIn(String gymId, String token) async {
    try {
      await ref.read(gymAccessProvider.notifier).performQrCheckIn(gymId, token);
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
        _errorMessage = 'Network error — please check your connection.';
        _processed = false;
      });
      _scanner.start();
    }
  }

  void _retry() => setState(() {
    _errorMessage = null;
    _processed = false;
  });

  @override
  Widget build(BuildContext context) {
    final accessState = ref.watch(gymAccessProvider);
    final isValidating = accessState is GymAccessValidating;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Stack(
              children: [
                _QrScannerView(
                  scanner: _scanner,
                  onDetect: _onDetect,
                  errorMessage: _errorMessage,
                  onRetry: _retry,
                  onBack: () => Navigator.of(context, rootNavigator: true).pop(false),
                ),
                if (isValidating) _buildValidatingOverlay(),
              ],
            ),
            const _PhoneKeyView(),
          ],
        ),
        bottomNavigationBar: Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppTheme.primaryBrand,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'QR Scanner', icon: Icon(Icons.qr_code_scanner, size: 20)),
                Tab(text: 'Phone Key', icon: Icon(Icons.nfc, size: 20)),
              ],
            ),
          ),
        ),
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
            const CircularProgressIndicator(color: AppTheme.primaryBrand, strokeWidth: 3),
            const SizedBox(height: 20),
            Text('Verifying access…', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _QrScannerView extends StatefulWidget {
  final MobileScannerController scanner;
  final void Function(BarcodeCapture) onDetect;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _QrScannerView({
    required this.scanner,
    required this.onDetect,
    required this.errorMessage,
    required this.onRetry,
    required this.onBack,
  });

  @override
  State<_QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<_QrScannerView> with TickerProviderStateMixin {
  late final AnimationController _scanLineCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scanLineAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanLineAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: widget.scanner,
            fit: BoxFit.cover,
            onDetect: widget.onDetect,
            errorBuilder: (context, error, child) => _buildCameraError(error),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [Colors.transparent, Colors.black.withValues(alpha: 0.78)]),
            ),
          ),
        ),
        _buildScanViewport(),
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                GestureDetector(onTap: widget.onBack, child: _iconButton(Icons.arrow_back)),
                const Spacer(),
                GestureDetector(onTap: () => widget.scanner.toggleTorch(), child: _iconButton(Icons.flashlight_on)),
              ]),
            ),
          ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Scan to Enter', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (widget.errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(widget.errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                ),
                TextButton(onPressed: widget.onRetry, child: const Text('Try Again', style: TextStyle(color: AppTheme.primaryBrand))),
              ] else
                Text('Scan the QR code at the gym entrance', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanViewport() {
    return Center(
      child: ScaleTransition(
        scale: _pulseAnim,
        child: SizedBox(
          width: 260, height: 260,
          child: Stack(
            children: [
              const _Corner(alignment: Alignment.topLeft, corners: [true, false, false, true]),
              const _Corner(alignment: Alignment.topRight, corners: [true, true, false, false]),
              const _Corner(alignment: Alignment.bottomLeft, corners: [false, false, true, true]),
              const _Corner(alignment: Alignment.bottomRight, corners: [false, true, true, false]),
              AnimatedBuilder(
                animation: _scanLineAnim,
                builder: (_, __) => Positioned(
                  left: 12, right: 12,
                  top: 12 + (_scanLineAnim.value * 236),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.transparent, AppTheme.primaryBrand.withValues(alpha: 0.8), AppTheme.primaryBrand, AppTheme.primaryBrand.withValues(alpha: 0.8), Colors.transparent]),
                      boxShadow: [BoxShadow(color: AppTheme.primaryBrand.withValues(alpha: 0.5), blurRadius: 8)],
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

  Widget _buildCameraError(MobileScannerException error) {
    final bool isPermDenied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_photography, color: Colors.red.withValues(alpha: 0.8), size: 40),
          const SizedBox(height: 24),
          Text(isPermDenied ? 'Camera Permission Denied' : 'Camera Error', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(isPermDenied ? 'Enable camera access in Settings.' : 'Unable to start camera.', style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: isPermDenied ? openAppSettings : widget.onRetry, child: Text(isPermDenied ? 'Open Settings' : 'Try Again')),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon) {
    return Container(
      height: 40, width: 40,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.5), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _PhoneKeyView extends ConsumerWidget {
  const _PhoneKeyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nfcState = ref.watch(nfcKeyProvider);
    final membershipState = ref.watch(membershipProvider);

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildKeyVisual(nfcState),
          const SizedBox(height: 40),
          const Text('Virtual Gym Key', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(_getStatusMessage(nfcState.status), style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 48),
          if (nfcState.status.isEnrolled && nfcState.status.isEnabled)
            _buildReadyControls(context, ref, nfcState)
          else if (!nfcState.status.isEnrolled)
            _buildEnrollSection(context, ref, membershipState, nfcState)
          else if (!nfcState.status.isSupported)
            const PremiumStateCard(icon: Icons.error_outline, title: 'Not Supported', subtitle: 'NFC/HCE door access is not supported.', actionLabel: null)
          else
            const CircularProgressIndicator(color: AppTheme.primaryBrand),
        ],
      ),
    );
  }

  Widget _buildKeyVisual(NfcKeyState state) {
    final bool isActive = state.status.isEnrolled && state.status.isEnabled;
    return Container(
      height: 200, width: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppTheme.primaryBrand.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: isActive ? AppTheme.primaryBrand.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1), width: 2),
        boxShadow: isActive ? [BoxShadow(color: AppTheme.primaryBrand.withValues(alpha: 0.1), blurRadius: 40, spreadRadius: 10)] : null,
      ),
      child: Center(child: Icon(isActive ? Icons.contactless : Icons.phonelink_lock, color: isActive ? AppTheme.primaryBrand : Colors.white24, size: 80)),
    );
  }

  Widget _buildReadyControls(BuildContext context, WidgetRef ref, NfcKeyState state) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.2))),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.primaryBrand, size: 24),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Key is Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Hold phone near gym reader', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
              Switch(value: true, onChanged: (val) => ref.read(nfcKeyProvider.notifier).togglePower(val), activeThumbColor: AppTheme.primaryBrand),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextButton(onPressed: () => ref.read(nfcKeyProvider.notifier).unenroll('DEFAULT'), child: const Text('Deactivate Key', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildEnrollSection(BuildContext context, WidgetRef ref, MembershipState membership, NfcKeyState state) {
    if (membership is! MembershipLoaded || membership.memberships.isEmpty) {
      return const Text('Active membership required.', style: TextStyle(color: Colors.white38));
    }
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: state.isEnrolling ? null : () => ref.read(nfcKeyProvider.notifier).enroll(membership.memberships.first.gymId),
            icon: state.isEnrolling ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.vpn_key),
            label: Text(state.isEnrolling ? 'Activating...' : 'Activate Phone Key', style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ),
        if (state.error != null) ...[const SizedBox(height: 12), Text(state.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))],
      ],
    );
  }

  String _getStatusMessage(PhoneKeyStatus status) {
    if (!status.isSupported) return 'NFC HCE is not supported on this device.';
    if (!status.isEnrolled) return 'Activate your virtual key to enter without scanning QR codes.';
    if (!status.isEnabled) return 'NFC Key is currently disabled. Enable it to use door access.';
    return 'Your phone is now a virtual key.\nHold it near the reader to enter.';
  }
}

class _Corner extends StatelessWidget {
  final Alignment alignment;
  final List<bool> corners;
  const _Corner({required this.alignment, required this.corners});
  @override
  Widget build(BuildContext context) {
    return Align(alignment: alignment, child: SizedBox(width: 28, height: 28, child: CustomPaint(painter: _CornerPainter(corners, 3.0))));
  }
}

class _CornerPainter extends CustomPainter {
  final List<bool> sides;
  final double thickness;
  const _CornerPainter(this.sides, this.thickness);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.primaryBrand..strokeWidth = thickness..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final w = size.width, h = size.height;
    if (sides[0]) canvas.drawLine(Offset.zero, Offset(w, 0), paint);
    if (sides[1]) canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
    if (sides[2]) canvas.drawLine(Offset(0, h), Offset(w, h), paint);
    if (sides[3]) canvas.drawLine(Offset.zero, Offset(0, h), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
