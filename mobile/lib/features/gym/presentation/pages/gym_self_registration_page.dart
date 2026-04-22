import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../providers/gym_register_provider.dart';
import '../providers/membership_provider.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';
import '../../../../core/config/app_config.dart';

class GymSelfRegistrationPage extends ConsumerStatefulWidget {
  final String gymId;
  final String registrationCode;

  const GymSelfRegistrationPage({
    super.key,
    required this.gymId,
    required this.registrationCode,
  });

  @override
  ConsumerState<GymSelfRegistrationPage> createState() =>
      _GymSelfRegistrationPageState();
}

class _GymSelfRegistrationPageState
    extends ConsumerState<GymSelfRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  final _dobCtrl = TextEditingController();
  final _personalNumCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _healthCtrl = TextEditingController();

  File? _selfieFile;
  File? _idFile;
  bool _obscurePass = true;
  bool _hasAutoSubmitted = false;
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load gym config
      ref
          .read(gymRegisterProvider.notifier)
          .loadConfig(widget.gymId, widget.registrationCode);

      // Pre-fill user data using both Auth (Account) and ProfileSync (Live/Cache)
      final user = ref.read(currentUserProvider);
      final profile = ref.read(profileSyncProvider);

      if (user != null || profile.fullName.isNotEmpty) {
        _nameCtrl.text = profile.fullName.isNotEmpty ? profile.fullName : (user?.fullName ?? '');
        _emailCtrl.text = profile.email.isNotEmpty ? profile.email : (user?.email ?? '');
        _dobCtrl.text = profile.dob.isNotEmpty ? profile.dob : (user?.dob ?? '');
        _phoneCtrl.text = profile.phoneNumber.isNotEmpty ? profile.phoneNumber : (user?.phoneNumber ?? '');
        _addressCtrl.text = profile.address.isNotEmpty ? profile.address : (user?.address ?? '');
        _personalNumCtrl.text = profile.personalNumber.isNotEmpty ? profile.personalNumber : (user?.personalNumber ?? '');
        _healthCtrl.text = profile.noMedicalConditions 
            ? 'No medical conditions' 
            : (profile.medicalConditions.isNotEmpty 
                ? profile.medicalConditions 
                : (user?.noMedicalConditions == true ? 'No medical conditions' : (user?.medicalConditions ?? '')));
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _dobCtrl.dispose();
    _personalNumCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _healthCtrl.dispose();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isSelfie) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: isSelfie ? CameraDevice.front : CameraDevice.rear,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isSelfie) {
          _selfieFile = File(picked.path);
        } else {
          _idFile = File(picked.path);
        }
      });
    }
  }

  Future<void> _submit(GymRegisterConfigLoaded config) async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    final formData = <String, dynamic>{
      'fullName': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'password': _passCtrl.text,
      if (config.requirements.dateOfBirth && _dobCtrl.text.isNotEmpty)
        'dateOfBirth': _dobCtrl.text,
      if (config.requirements.personalNumber &&
          _personalNumCtrl.text.isNotEmpty)
        'personalNumber': _personalNumCtrl.text.trim(),
      if (config.requirements.phoneNumber && _phoneCtrl.text.isNotEmpty)
        'phoneNumber': _phoneCtrl.text.trim(),
      if (config.requirements.address && _addressCtrl.text.isNotEmpty)
        'address': _addressCtrl.text.trim(),
      if (config.requirements.healthInfo) ...(() {
          final h = _healthCtrl.text.trim();
          // 'No medical conditions' is a display-only placeholder — never send it as real data.
          if (h.isNotEmpty && h != 'No medical conditions') return {'healthInfo': h};
          return <String, dynamic>{};
        })(),
    };

    final user = ref.read(currentUserProvider);

    await ref.read(gymRegisterProvider.notifier).submitRegistration(
          gymId: widget.gymId,
          registrationCode: widget.registrationCode,
          formData: formData,
          selfieFile: config.requirements.selfiePhoto ? _selfieFile : null,
          idFile: config.requirements.idPhoto ? _idFile : null,
          existingSelfieUrl: config.requirements.selfiePhoto && _selfieFile == null ? user?.avatarUrl : null, // Fallback to existing
          existingIdUrl: config.requirements.idPhoto && _idFile == null ? user?.idPhotoUrl : null, // Fallback to existing
        );
  }


  @override
  Widget build(BuildContext context) {
    final gymState = ref.watch(gymRegisterProvider);
    final user = ref.watch(currentUserProvider);
    final isAuthenticated = user != null;

    // Reactive Pre-fill: If profile syncs late, populate the fields
    ref.listen<ProfileSyncState>(profileSyncProvider, (previous, next) {
      if (next.isInitialized && !next.isSyncing) {
        if (_nameCtrl.text.isEmpty && next.fullName.isNotEmpty) _nameCtrl.text = next.fullName;
        if (_emailCtrl.text.isEmpty && next.email.isNotEmpty) _emailCtrl.text = next.email;
        if (_dobCtrl.text.isEmpty && next.dob.isNotEmpty) _dobCtrl.text = next.dob;
        if (_phoneCtrl.text.isEmpty && next.phoneNumber.isNotEmpty) _phoneCtrl.text = next.phoneNumber;
        if (_addressCtrl.text.isEmpty && next.address.isNotEmpty) _addressCtrl.text = next.address;
        if (_personalNumCtrl.text.isEmpty && next.personalNumber.isNotEmpty) _personalNumCtrl.text = next.personalNumber;
        
        // Handle health information pre-fill
        if (_healthCtrl.text.isEmpty) {
          if (next.noMedicalConditions) {
            _healthCtrl.text = 'No medical conditions';
          } else if (next.medicalConditions.isNotEmpty) {
            _healthCtrl.text = next.medicalConditions;
          }
        }
      }
    });

    // Aggressive Pre-fill: Ensure email is NEVER empty if authenticated
    if (isAuthenticated && _emailCtrl.text.isEmpty && user.email.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _emailCtrl.text.isEmpty && user.email.isNotEmpty) {
          _emailCtrl.text = user.email;
        }
      });
    }

    final membershipState = ref.watch(membershipProvider);
    bool isActuallyMember = false;
    if (membershipState is MembershipLoaded) {
      isActuallyMember = membershipState.memberships.any(
        (m) => m.gymId == widget.gymId && (m.isActive || m.isPending),
      );
    }

    // Zero-Friction: Automatic Profile Sync
    if (gymState is GymRegisterConfigLoaded && isAuthenticated && !isActuallyMember && !_hasAutoSubmitted) {
      if (_isProfileComplete(gymState, user)) {
        // All requirements met! Auto-submit to avoid redundant form filling.
        _hasAutoSubmitted = true;
        Future.microtask(() => _submit(gymState));
      }
    }

    ref.listen<GymRegisterState>(gymRegisterProvider, (previous, next) {
      if (next is GymRegisterSuccess) {
        // Celebrate!
        _confetti.play();

        // Refresh user profile to sync any newly filled data (DOB, Phone, etc.)
        ref.read(authNotifierProvider.notifier).refreshProfile();

        // Start pulling fresh data
        ref.read(membershipProvider.notifier).fetch();

        // Premium Experience: Wait for the membership to appear before redirecting.
        // This prevents the "No Membership" flash on the Gym page.
        _waitForMembershipAndRedirect();
      }
    });

    // Auto-reactivate if member is inactive but has a future end date
    if (membershipState is MembershipLoaded && !isActuallyMember && !_hasAutoSubmitted) {
      final inactiveMember = membershipState.memberships.firstWhere(
        (m) => m.gymId == widget.gymId,
        orElse: () => const GymMembershipInfo(id: '', gymId: '', gymName: '', status: '', endDate: ''),
      );
      
      if (inactiveMember.id.isNotEmpty) {
        DateTime? endDate;
        try { endDate = DateTime.parse(inactiveMember.endDate); } catch (_) {}
        if (endDate != null && endDate.isAfter(DateTime.now()) && 
            gymState is GymRegisterConfigLoaded && _isProfileComplete(gymState, user)) {
          // Future valid subscription found but status is not ACTIVE/PENDING.
          // Auto-trigger reactivation ONLY if profile meets requirements.
          _hasAutoSubmitted = true;
          Future.microtask(() => _submit(gymState));
        }
      }
    }

    // Zero-Friction: If already a member, auto-redirect to Gym tab
    ref.listen<MembershipState>(membershipProvider, (previous, next) {
      if (next is MembershipLoaded) {
        final isAlreadyMember = next.memberships.any((m) => m.gymId == widget.gymId && m.isActive);
        if (isAlreadyMember) {
          context.go('/gym');
        }
      }
    });

    // Success state UI (shown during the 2s delay)
    if (gymState is GymRegisterSuccess) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Stack(
          children: [
            _SuccessScreen(
              gymName: gymState.gymName,
              isNewUser: gymState.isNewUser,
              onDone: () {
                ref.read(gymRegisterProvider.notifier).reset();
                context.go('/gym');
              },
            ),
            // Confetti overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  AppTheme.primaryBrand,
                  Colors.white,
                  Color(0xFF2ECC71),
                  Color(0xFFF1C40F),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            ref.read(gymRegisterProvider.notifier).reset();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/challenge');
            }
          },
        ),
        title: const Text(
          'Join Gym',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          _CloudSyncIndicator(),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _buildBody(gymState, isAuthenticated, isActuallyMember, user),
      ),
    );
  }

  bool _isProfileComplete(GymRegisterConfigLoaded config, UserEntity? user) {
    if (user == null) return false;
    final reqs = config.requirements;

    // Check if all required text fields are satisfied by the current profile
    bool nameOk = (user.fullName ?? '').isNotEmpty;
    bool emailOk = user.email.isNotEmpty;
    bool dobOk = !reqs.dateOfBirth || (user.dob ?? '').isNotEmpty;
    bool phoneOk = !reqs.phoneNumber || (user.phoneNumber ?? '').isNotEmpty;
    bool addressOk = !reqs.address || (user.address ?? '').isNotEmpty;
    bool personalNumOk = !reqs.personalNumber || (user.personalNumber ?? '').isNotEmpty;
    bool healthOk = !reqs.healthInfo || (user.medicalConditions ?? '').isNotEmpty;

    // Check if photos are satisfied (either local file or existing URL)
    bool selfieOk = !reqs.selfiePhoto || _selfieFile != null || (user.avatarUrl ?? '').isNotEmpty;
    bool idPhotoOk = !reqs.idPhoto || _idFile != null || (user.idPhotoUrl ?? '').isNotEmpty;

    return nameOk && emailOk && dobOk && phoneOk && addressOk && personalNumOk && healthOk && selfieOk && idPhotoOk;
  }

  void _waitForMembershipAndRedirect() {
    int attempts = 0;
    const maxAttempts = 8; // Max 4 seconds (8 * 500ms)

    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final membershipState = ref.read(membershipProvider);
      final bool found = membershipState is MembershipLoaded &&
          membershipState.memberships.any((m) => m.gymId == widget.gymId);

      attempts++;

      // If found OR we reached 2 seconds (minimum celebration) and max attempts
      if (found || attempts >= maxAttempts) {
        timer.cancel();
        // Ensure at least 2 seconds for confetti
        final remaining = 2000 - (attempts * 500);
        Future.delayed(Duration(milliseconds: remaining > 0 ? remaining : 0), () {
          if (mounted) context.go('/gym');
        });
      } else if (attempts % 2 == 0) {
        // Refresh every second if not found
        ref.read(membershipProvider.notifier).fetch();
      }
    });
  }

  Widget _buildBody(GymRegisterState state, bool isAuthenticated, bool isActuallyMember, UserEntity? user) {
    if (state is GymRegisterConfigLoaded) return _buildForm(state, isAuthenticated, isActuallyMember, user);
    if (state is GymRegisterSubmitting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryBrand),
            const SizedBox(height: 16),
            Text(
              _hasAutoSubmitted ? 'Synchronizing Profile…' : 'Joining Gym…',
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (_hasAutoSubmitted) ...[
              const SizedBox(height: 8),
              const Text(
                'Linking your identity data automatically',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
      );
    }
    if (state is GymRegisterError) return _buildError(state.message);
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.primaryBrand),
    );
  }

  Widget _buildForm(
      GymRegisterConfigLoaded config, bool isAuthenticated, bool isActuallyMember, UserEntity? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gym Name Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'JOINING',
                    style: TextStyle(
                      color: AppTheme.primaryBrand,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    config.gymName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Complete the form below to register as a member',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
            
            const SizedBox(height: 24),

            // ── Core fields ──────────────────────────────────────────────────
            _SectionLabel('Personal Details')
                .animate()
                .fadeIn(delay: 100.ms)
                .slideX(begin: -0.1),
            _field(
              controller: _nameCtrl,
              label: 'Full Name',
              icon: Icons.person_outline,
              required: true,
              validator: (v) =>
                  (v?.isEmpty ?? true) ? 'Full name is required' : null,
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
            
            // Email Field: If authenticated, we show it locked
            if (isAuthenticated)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user_outlined, color: AppTheme.primaryBrand, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Verified Email Address', 
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(user!.email, 
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.lock_outline, color: Colors.white24, size: 16),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1)
            else
              _field(
                controller: _emailCtrl,
                label: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                required: true,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Email is required';
                  if (!v!.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

            if (!isAuthenticated) 
              _passwordField().animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

            // ── Optional required fields ────────────────────────────────────
            if (config.requirements.dateOfBirth) ...[
              _SectionLabel('Additional Information')
                  .animate()
                  .fadeIn(delay: 300.ms)
                  .slideX(begin: -0.1),
              _field(
                controller: _dobCtrl,
                label: 'Date of Birth',
                icon: Icons.calendar_today_outlined,
                hint: 'YYYY-MM-DD',
                keyboardType: TextInputType.datetime,
                inputFormatters: [DateInputFormatter()],
                required: true,
                validator: (v) =>
                    (v?.isEmpty ?? true) ? 'Date of birth is required' : null,
              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),
            ],
            if (config.requirements.personalNumber)
              _field(
                controller: _personalNumCtrl,
                label: 'Personal / ID Number',
                icon: Icons.badge_outlined,
                required: true,
                validator: (v) => (v?.isEmpty ?? true)
                    ? 'Personal number is required'
                    : null,
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
            if (config.requirements.phoneNumber)
              _field(
                controller: _phoneCtrl,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneInputFormatter()],
                required: true,
                validator: (v) =>
                    (v?.isEmpty ?? true) ? 'Phone number is required' : null,
              ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1),
            if (config.requirements.address)
              _field(
                controller: _addressCtrl,
                label: 'Home Address',
                icon: Icons.home_outlined,
                required: true,
                maxLines: 2,
                validator: (v) =>
                    (v?.isEmpty ?? true) ? 'Address is required' : null,
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
            if (config.requirements.healthInfo)
              _field(
                controller: _healthCtrl,
                label: 'Health Information',
                icon: Icons.health_and_safety_outlined,
                hint: 'Any relevant health conditions or notes...',
                maxLines: 3,
                required: true,
                validator: (v) => (v?.isEmpty ?? true)
                    ? 'Health information is required'
                    : null,
              ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1),

            // ── Photo uploads ────────────────────────────────────────────────
            if (config.requirements.selfiePhoto ||
                config.requirements.idPhoto) ...[
              _SectionLabel('Photos')
                  .animate()
                  .fadeIn(delay: 600.ms)
                  .slideX(begin: -0.1),
              if (config.requirements.selfiePhoto)
                _PhotoPicker(
                  label: 'Selfie Photo',
                  description: 'Take a photo with your face clearly visible',
                  icon: Icons.face,
                  file: _selfieFile,
                  existingUrl: user?.avatarUrl,
                  onPick: () => _pickImage(true),
                  required: true,
                ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.1),
              if (config.requirements.idPhoto)
                _PhotoPicker(
                  label: 'ID / Passport Photo',
                  description: 'Upload a clear photo of your official ID',
                  icon: Icons.credit_card_outlined,
                  file: _idFile,
                  existingUrl: user?.idPhotoUrl,
                  onPick: () => _pickImage(false),
                  required: true,
                ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),
            ],

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isActuallyMember ? () => context.go('/gym') : () => _submit(config),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBrand,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isActuallyMember ? 'GO TO GYM' : 'JOIN GYM',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 800.ms).scale(begin: const Offset(0.9, 0.9)),
          ],
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _passCtrl,
        obscureText: _obscurePass,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          labelText: 'Password *',
          labelStyle: const TextStyle(color: AppTheme.textSecondary),
          prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryBrand, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white38,
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
          filled: true,
          fillColor: AppTheme.surfaceDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primaryBrand),
          ),
        ),
        validator: (v) {
          if (v?.isEmpty ?? true) return 'Password is required';
          if (v!.length < 6) return 'Password must be at least 6 characters';
          return null;
        },
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? hint,
    int maxLines = 1,
    bool required = false,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        enabled: enabled,
        style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          labelText: required ? '$label *' : label,
          labelStyle: TextStyle(color: enabled ? AppTheme.textSecondary : Colors.white24),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: Icon(icon, color: AppTheme.primaryBrand, size: 20),
          filled: true,
          fillColor: enabled ? AppTheme.surfaceDark : AppTheme.surfaceDark.withValues(alpha: 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.primaryBrand, width: 2),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildError(String message) {
    bool isAlreadyRegistered = message.toLowerCase().contains('already registered');
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAlreadyRegistered ? Icons.info_outline : Icons.error_outline, 
              color: isAlreadyRegistered ? AppTheme.primaryBrand : Colors.red, 
              size: 48
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (isAlreadyRegistered) {
                  context.go('/gym');
                } else {
                  ref.read(gymRegisterProvider.notifier)
                      .loadConfig(widget.gymId, widget.registrationCode);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBrand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isAlreadyRegistered ? 'GO TO GYM' : 'Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primaryBrand,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ─── Photo Picker ─────────────────────────────────────────────────────────────

class _PhotoPicker extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final File? file;
  final String? existingUrl;
  final VoidCallback onPick;
  final bool required;

  const _PhotoPicker({
    required this.label,
    required this.description,
    required this.icon,
    required this.file,
    this.existingUrl,
    required this.onPick,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onPick,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasFile
                ? AppTheme.primaryBrand.withValues(alpha: 0.08)
                : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasFile
                  ? AppTheme.primaryBrand.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                child: hasFile
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(file!, fit: BoxFit.cover),
                      )
                    : existingUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Opacity(
                            opacity: 0.8,
                            child: Image.network(
                              AppConfig.resolveMediaUrl(existingUrl) ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                Icon(icon, color: Colors.white38, size: 22),
                            ),
                          ),
                        )
                      : Icon(icon, color: Colors.white38, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      required ? '$label *' : label,
                      style: TextStyle(
                        color: hasFile ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasFile ? 'Tap to change photo' : (existingUrl != null ? 'Using photo from profile' : description),
                      style: TextStyle(
                        color: (hasFile || existingUrl != null) ? AppTheme.primaryBrand.withValues(alpha: 0.7) : Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                hasFile ? Icons.check_circle : Icons.camera_alt_outlined,
                color: hasFile
                    ? AppTheme.primaryBrand
                    : Colors.white24,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Success Screen ───────────────────────────────────────────────────────────

class _SuccessScreen extends StatelessWidget {
  final String gymName;
  final bool isNewUser;
  final VoidCallback onDone;

  const _SuccessScreen({
    required this.gymName,
    required this.isNewUser,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Animated Checkmark
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
              border: Border.all(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.45),
                  width: 2),
            ),
            child: const Icon(Icons.check_circle_outline,
                color: Color(0xFF2ECC71), size: 64),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).rotate(begin: -0.2, end: 0),
          const SizedBox(height: 32),
          const Text(
            'Registration Confirmed!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900),
          ).animate().fadeIn(delay: 200.ms).moveY(begin: 10, end: 0),
          const SizedBox(height: 16),
          Text(
            isNewUser
                ? 'Welcome to $gymName! Your membership has been submitted and is pending final approval.'
                : 'Great! Your membership at $gymName has been updated successfully.',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 15, height: 1.5),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBrand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('GO TO GYM DASHBOARD',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }
}

class _CloudSyncIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(profileSyncProvider.select((s) => s.isSyncing));
    if (!isSyncing) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryBrand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryBrand),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'SYNCING',
            style: TextStyle(
              color: AppTheme.primaryBrand,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8));
  }
}

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) {
      return newValue;
    }
    var newText = '';
    text = text.replaceAll('-', '');
    for (var i = 0; i < text.length; i++) {
      newText += text[i];
      if ((i == 3 || i == 5) && i != text.length - 1) {
        newText += '-';
      }
    }
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) {
      return newValue;
    }
    var newText = '';
    text = text.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < text.length; i++) {
      if (i == 0) newText += '(';
      newText += text[i];
      if (i == 2) newText += ') ';
      if (i == 5) newText += '-';
    }
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
