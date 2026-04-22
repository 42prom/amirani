import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/config/app_config.dart';
import '../providers/gym_provider.dart';
import '../providers/gym_access_provider.dart';
import '../providers/membership_provider.dart';
import 'gym_entry_page.dart';
import '../../../../theme/app_theme.dart';
import '../../../profile/presentation/widgets/profile_settings_modal.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/nfc_hce_service.dart';
import '../../domain/entities/trainer_entity.dart';
import '../providers/support_provider.dart';
import '../providers/trainer_assignment_provider.dart';
import '../../data/datasources/trainer_assignment_data_source.dart';
import '../../../../core/widgets/premium_state_card.dart';
import '../../data/datasources/support_remote_data_source.dart';
import '../../../../core/utils/app_notifications.dart';
import 'trainer_chat_page.dart';
import 'package:confetti/confetti.dart';
import '../providers/announcements_provider.dart';
import '../../../../core/providers/storage_providers.dart';
import '../../data/models/announcement_model.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/providers/day_selector_providers.dart';
import '../providers/sessions_provider.dart';
// import '../../data/models/session_model.dart';
import '../widgets/session_booking_sheet.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/user_avatar.dart';

class GymPage extends ConsumerStatefulWidget {
  const GymPage({super.key});

  @override
  ConsumerState<GymPage> createState() => _GymPageState();
}

class _GymPageState extends ConsumerState<GymPage> {
  late ConfettiController _confettiController;
  bool _hasCelebrated = false;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _checkCelebrationStatus();
    Future.microtask(() {
      final authState = ref.read(authNotifierProvider);
      if (authState is! AuthAuthenticated) return;

      // Staff (BRANCH_ADMIN, GYM_OWNER, SUPER_ADMIN, TRAINER) — use managedGymId
      final managedGymId = authState.user.managedGymId;
      if (managedGymId != null) {
        ref.read(gymNotifierProvider.notifier).fetchGymDetails(managedGymId);
        return;
      }

      // load from active check-in or pending membership
      final accessState = ref.read(gymAccessProvider);
      final membershipState = ref.read(membershipProvider);

      String? gymIdToFetch;
      if (accessState is GymAccessAdmitted) {
        gymIdToFetch = accessState.checkIn.gymId;
      } else if (membershipState is MembershipLoaded) {
        for (final m in membershipState.memberships) {
          if (m.isActive || m.isPending) {
            gymIdToFetch = m.gymId;
            break;
          }
        }
      }

      if (gymIdToFetch != null) {
        ref.read(gymNotifierProvider.notifier).fetchGymDetails(gymIdToFetch);
        ref.read(sessionsProvider.notifier).fetchSessions(gymIdToFetch);
      }
    });
    // Check session expiry every minute
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      ref.read(gymAccessProvider.notifier).checkIfExpired();
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(gymNotifierProvider);
    final profileSync = ref.watch(profileSyncProvider);
    final authState = ref.watch(authNotifierProvider);
    final accessState = ref.watch(gymAccessProvider);

    // When a member successfully checks in, load gym details for their gym.
    ref.listen<GymAccessState>(gymAccessProvider, (previous, next) {
      if (next is GymAccessAdmitted && previous is! GymAccessAdmitted) {
        ref.read(gymNotifierProvider.notifier).fetchGymDetails(next.checkIn.gymId);
      }
    });

    // Determine role — backend sends uppercase enum strings (GYM_MEMBER, GYM_OWNER, …)
    final String? role =
        authState is AuthAuthenticated ? authState.user.role : null;
    const staffRoles = {'BRANCH_ADMIN', 'GYM_OWNER', 'TRAINER', 'SUPER_ADMIN'};
    final bool isStaff = staffRoles.contains(role);
    final bool isMember = !isStaff;

    final bool isAdmitted = accessState is GymAccessAdmitted &&
        (accessState).checkIn.isActive;

    final membershipState = ref.watch(membershipProvider);

    // Load gym details from active or pending membership when not yet checked in
    ref.listen<MembershipState>(membershipProvider, (_, next) {
      if (next is MembershipLoaded) {
        GymMembershipInfo? current;
        for (final m in next.memberships) {
          if (m.isActive || m.isPending) { current = m; break; }
        }
        if (current != null) {
          ref.read(gymNotifierProvider.notifier).fetchGymDetails(current.gymId);
          
          // Celebration trigger: transition to ACTIVE
          if (current.isActive && !_hasCelebrated) {
            _confettiController.play();
            _markCelebrated();
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(profileSync),
                Expanded(
                  // Handle loading state with a premium shimmer
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final mFuture = ref.read(membershipProvider.notifier).fetch();
                      final gymState = ref.read(gymNotifierProvider);
                      String? gymId;
                      if (gymState is GymLoaded) {
                        gymId = gymState.gym.id;
                      } else {
                        final membershipState = ref.read(membershipProvider);
                        if (membershipState is MembershipLoaded) {
                          gymId = membershipState.memberships
                              .where((m) => m.isActive || m.isPending)
                              .firstOrNull
                              ?.gymId;
                        }
                      }

                      if (gymId != null) {
                        ref.invalidate(announcementsProvider(gymId));
                        await Future.wait<void>([
                          mFuture,
                          ref.read(gymNotifierProvider.notifier).fetchGymDetails(gymId),
                          ref.read(sessionsProvider.notifier).fetchSessions(gymId),
                          ref.read(trainerAssignmentProvider.notifier).refreshStatus(gymId),
                          ref.read(announcementsProvider(gymId).future),
                        ]);
                      } else {
                        await mFuture;
                      }
                    },
                    backgroundColor: AppTheme.surfaceDark,
                    color: AppTheme.primaryBrand,
                    child: membershipState is MembershipInitial || membershipState is MembershipLoading
                        ? _buildLoadingShimmer()
                        : (isMember && (membershipState is MembershipLoaded && 
                            !membershipState.memberships.any((m) => m.isActive || m.isPending)))
                            ? _buildNoMembershipView()
                            : _buildMainContent(accessState, isAdmitted),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppTheme.primaryBrand,
                Colors.white,
                Colors.amber,
                Colors.orange,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── No membership — prompt user to join a gym ────────────────────────────

  Widget _buildNoMembershipView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryBrand.withValues(alpha: 0.12),
                  border: Border.all(
                      color: AppTheme.primaryBrand.withValues(alpha: 0.35),
                      width: 1.5),
                ),
                child: Icon(Icons.fitness_center,
                    color: AppTheme.primaryBrand, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Gym Membership',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'You don\'t have an active gym membership yet. Ask your gym to register you, or scan their QR code to join.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.qr_code_scanner, size: 20),
                  label: const Text('Scan Gym QR Code',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBrand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.1),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAwaitingApprovalBanner() {
    return Container(
      width: double.infinity,
      color: Colors.blue.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: const Row(
        children: [
          Icon(Icons.hourglass_empty, color: Colors.blue, size: 18),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Awaiting Membership Approval',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openScanner() async {
    // rootNavigator: true ensures the scanner covers the full screen,
    // including the bottom navigation bar rendered by the shell route.
    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const GymEntryPage(),
      ),
    );
    // Flagship Feature: Refresh data immediately upon returning from registration scan
    ref.read(membershipProvider.notifier).fetch();
  }

  void _openDoor() {
    final accessState = ref.read(gymAccessProvider);
    _showDoorAccessSheet(accessState, accessState is GymAccessAdmitted);
  }

  // ─── Full gym content (admitted member or staff) ──────────────────────────

  Widget _buildMainContent(GymAccessState accessState, bool isAdmitted) {
    final membershipState = ref.watch(membershipProvider);
    GymMembershipInfo? currentMembership;
    if (membershipState is MembershipLoaded) {
      for (final m in membershipState.memberships) {
        if (m.isActive || m.isPending) { 
          currentMembership = m; 
          break; 
        }
      }
    }

    final bool isPending = currentMembership?.isPending ?? false;

    if (isPending && !isAdmitted) {
      return _buildPendingApprovalView(currentMembership?.gymName ?? 'the gym');
    }

    return _buildGymContent(accessState, isAdmitted);
  }

  Widget _buildPendingApprovalView(String gymName) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.hourglass_empty, color: Colors.blue, size: 36),
                  ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  const Text(
                    'Membership Pending',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome to $gymName! Your membership is currently awaiting approval from the branch manager.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You will be notified once your membership is approved.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              'While you wait...',
              style: TextStyle(color: AppTheme.primaryBrand, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            const SizedBox(height: 20),
            _buildPendingTipRow(Icons.person_outline, 'Complete your fitness profile'),
            _buildPendingTipRow(Icons.restaurant_menu, 'Check out recommended nutrition'),
            _buildPendingTipRow(Icons.auto_awesome, 'Explore AI-powered workout plans'),
          ],
        ),
      ).animate().fadeIn(duration: 800.ms).moveY(begin: 30, end: 0),
    );
  }

  Widget _buildPendingTipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white24, size: 18),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildGymContent(GymAccessState accessState, bool isAdmitted) {
    final admitted = accessState is GymAccessAdmitted ? accessState : null;

    // Resolve active or pending membership
    final membershipState = ref.watch(membershipProvider);
    GymMembershipInfo? currentMembership;
    if (membershipState is MembershipLoaded) {
      for (final m in membershipState.memberships) {
        if (m.isActive || m.isPending) { currentMembership = m; break; }
      }
    }
    final bool isPending = currentMembership?.isPending ?? false;
    final String? gymId =
        admitted?.checkIn.gymId ?? currentMembership?.gymId;
    final gymState = ref.watch(gymNotifierProvider);
    final String? gymName =
        admitted?.checkIn.gymName ??
            currentMembership?.gymName ??
            (gymState is GymLoaded ? gymState.gym.name : null);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
          if (isPending && !isAdmitted) ...[
            _buildAwaitingApprovalBanner(),
            const SizedBox(height: 16),
          ],

          _buildDaySelector(),
          const SizedBox(height: 16),

          // Admission banner (only for admitted members)
          if (isAdmitted) ...[
            _buildAdmissionBanner(
                admitted!.checkIn.gymName,
                admitted.checkIn.formattedAdmittedAt,
                admitted.checkIn.formattedExpiresAt),
            const SizedBox(height: 16),
          ],

          _buildActionButtons(accessState, isAdmitted, currentMembership != null),
          const SizedBox(height: 24),
          _buildMembershipCard(accessState, currentMembership),
          const SizedBox(height: 24),
          if (currentMembership != null && currentMembership.isActive)
            _buildAssignedTrainerCard(currentMembership, gymId),
          if (gymId != null) ...[
            const SizedBox(height: 32),
            _buildAnnouncementsSection(gymId),
            const SizedBox(height: 32),
            _buildUpcomingSessions(),
          ],
          const SizedBox(height: 32),
          _buildTrainersSection(),
          const SizedBox(height: 32),
          _buildGymUtilities(gymId),
          if (gymId != null && gymName != null) ...[
            const SizedBox(height: 12),
            _buildLeaveGymButton(gymId, gymName),
          ],
        ],
      ),
    );
  }

  // ─── Admission banner ─────────────────────────────────────────────────────

  Widget _buildAdmissionBanner(
      String gymName, String admittedAt, String expiresAt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A2A), Color(0xFF0F2318)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF2ECC71).withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
              border: Border.all(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.check_circle_outline,
                color: Color(0xFF2ECC71), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gymName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'In since $admittedAt · Until $expiresAt',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.4)),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(
                color: Color(0xFF2ECC71),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  Future<void> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit Gym Session?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Your active session will be closed. You can re-enter anytime by scanning the gym QR code again.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBrand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Exit',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(gymAccessProvider.notifier).clearAccess();
    }
  }

  // ─── Existing gym widgets ─────────────────────────────────────────────────

    Widget _buildHeader(ProfileSyncState profileSync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => ProfileSettingsModal.show(context),
                    child: UserAvatar(
                      imagePath: profileSync.profileImagePath,
                      displayName: profileSync.fullName,
                      size: 40,
                      badge: Container(
                        height: 12,
                        width: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryBrand,
                          border: Border.all(
                              color: AppTheme.backgroundDark, width: 2),
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
                          profileSync.firstName.isNotEmpty
                              ? profileSync.firstName
                              : (profileSync.fullName.isNotEmpty
                                  ? profileSync.fullName.split(' ')[0]
                                  : 'Your Name'),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ).animate().fadeIn(delay: 200.ms).moveX(begin: -10, end: 0),
                ],
              ),
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surfaceDark.withValues(alpha: 0.5),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05))),
                child:
                    const Icon(Icons.light_mode, color: Colors.white54, size: 20),
              )
            ],
          ),
          const SizedBox(height: 8),
          const _CloudSyncIndicator(),
        ],
      ),
    );
  }

  Widget _buildActionButtons(GymAccessState accessState, bool isAdmitted, bool hasMembership) {
    // ── Admitted member: Open Door (primary) + Leave Gym (secondary) ─────────
    if (isAdmitted) {
      return Row(
        children: [
          // Open Door — primary action, triggers door access system
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: _openDoor,
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2D9CDB), Color(0xFF1565C0)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2D9CDB).withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensor_door_outlined,
                        color: Colors.white, size: 28),
                    SizedBox(height: 6),
                    Text(
                      'Open Door',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'TAP TO ACCESS',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Leave Gym — check-out / end session
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _confirmExit,
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout,
                        color: Colors.red.withValues(alpha: 0.75), size: 26),
                    const SizedBox(height: 6),
                    Text(
                      'Leave',
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'CHECK OUT',
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.4),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ── Staff / unadmitted: Circular Door Access (Centered) ──────────────────
    return Center(
      child: GestureDetector(
        onTap: () => _showDoorAccessSheet(accessState, isAdmitted),
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2D9CDB), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2D9CDB).withValues(alpha: 0.4),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sensor_door_outlined,
                color: Colors.white,
                size: 42,
              ),
              const SizedBox(height: 8),
              const Text(
                'Door Access',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'TAP TO ENTER',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDoorAccessSheet(GymAccessState accessState, bool isAdmitted) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _DoorAccessSheet(
        accessState: accessState,
        isAdmitted: isAdmitted,
        onScanQr: () {
          Navigator.pop(context);
          _openScanner();
        },
      ),
    );
  }

  /// Returns a colour that reflects urgency: green → amber → red.
  Color _subscriptionColor(int? days) {
    if (days == null) return AppTheme.primaryBrand;
    if (days > 14) return AppTheme.primaryBrand;
    if (days > 7) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  Widget _buildMembershipCard(GymAccessState accessState, GymMembershipInfo? activeMembership) {
    final admitted = accessState is GymAccessAdmitted ? accessState : null;

    // ── Admitted: show live check-in details ─────────────────────────────────
    if (admitted != null) {
      final days = admitted.checkIn.daysRemaining;
      final plan = admitted.checkIn.planName;
      final double progress = days != null ? (days / 30.0).clamp(0.0, 1.0) : 0.0;
      final Color accentColor = _subscriptionColor(days);
      final bool isUrgent = days != null && days <= 7;
      final bool isWarning = days != null && days > 7 && days <= 14;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isUrgent
                ? const Color(0xFFE74C3C).withValues(alpha: 0.3)
                : isWarning
                    ? const Color(0xFFF39C12).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan ?? 'Membership',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            days != null ? '$days' : '—',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          if (days != null) ...[
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                days == 1 ? 'day left' : 'days left',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isUrgent) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: const Color(0xFFE74C3C).withValues(alpha: 0.9),
                                size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Expires soon — renew to keep access',
                              style: TextStyle(
                                color: const Color(0xFFE74C3C).withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(
                  height: 80,
                  width: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 7,
                        color: accentColor.withValues(alpha: 0.1),
                      ),
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        color: accentColor,
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Text(
                          days != null ? '${(progress * 100).round()}%' : '—',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: accentColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 12),
            // Renew button
            GestureDetector(
              onTap: () => AppNotifications.showInfo(context, 'Contact gym staff to renew your plan'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? const Color(0xFFE74C3C)
                      : isWarning
                          ? const Color(0xFFF39C12)
                          : accentColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: isUrgent ? 0.4 : 0.25),
                      blurRadius: isUrgent ? 12 : 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isUrgent ? Icons.refresh : Icons.card_membership,
                      color: isUrgent || isWarning ? Colors.white : Colors.black,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUrgent
                          ? 'Renew Now — Expires in $days ${days == 1 ? 'day' : 'days'}'
                          : 'Renew Plan',
                      style: TextStyle(
                        color: isUrgent || isWarning ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Not admitted: use activeMembership passed from parent ────────────────
    final active = activeMembership;

    if (active == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(children: [
          Expanded(
            child: Text('Loading membership…',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
          ),
        ]),
      );
    }

    // Parse end date and compute days remaining
    DateTime? endDate;
    try { endDate = DateTime.parse(active.endDate); } catch (_) {}
    final int daysLeft = endDate != null
        ? endDate.difference(DateTime.now()).inDays.clamp(0, 999)
        : 0;

    // 3-colour rule: >14 green · 7–14 orange · ≤7 red  (matches admitted branch thresholds)
    final bool isUrgentStatic  = daysLeft <= 7;
    final bool isWarningStatic = daysLeft > 7 && daysLeft <= 14;
    final Color circleColor = isUrgentStatic
        ? const Color(0xFFE74C3C)
        : isWarningStatic
            ? const Color(0xFFF39C12)
            : const Color(0xFF2ECC71);

    // Arc progress — 365 days = full circle; supports up to 999 displayed
    final double arcProgress = (daysLeft / 365.0).clamp(0.0, 1.0);

    // Adaptive font size so 3-digit numbers fit in the circle
    final double digitSize = daysLeft >= 100 ? 22.0 : 30.0;

    final borderColor = isUrgentStatic
        ? const Color(0xFFE74C3C).withValues(alpha: 0.35)
        : isWarningStatic
            ? const Color(0xFFF39C12).withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.05);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: gym info ──────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gym name
                Text(
                  active.gymName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // ACTIVE badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF2ECC71).withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Color(0xFF2ECC71),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                if (endDate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.35)),
                      const SizedBox(width: 6),
                      Text(
                        'Until ${endDate.day}/${endDate.month}/${endDate.year}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                if (isUrgentStatic || isWarningStatic) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: isUrgentStatic
                            ? const Color(0xFFE74C3C).withValues(alpha: 0.9)
                            : const Color(0xFFF39C12).withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          isUrgentStatic
                              ? 'Expires in $daysLeft ${daysLeft == 1 ? 'day' : 'days'} — renew to keep access'
                              : 'Renew soon — $daysLeft days remaining',
                          style: TextStyle(
                            color: isUrgentStatic
                                ? const Color(0xFFE74C3C).withValues(alpha: 0.85)
                                : const Color(0xFFF39C12).withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ── Right: days circle ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: circleColor.withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Track
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 10,
                    color: circleColor.withValues(alpha: 0.1),
                  ),
                  // Fill
                  CircularProgressIndicator(
                    value: arcProgress,
                    strokeWidth: 10,
                    color: circleColor,
                    strokeCap: StrokeCap.round,
                  ),
                  // Label
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$daysLeft',
                          style: TextStyle(
                            color: circleColor,
                            fontSize: digitSize,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          daysLeft == 1 ? 'day' : 'days',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'left',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 9,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveGymButton(String gymId, String gymName) {
    return GestureDetector(
      onTap: () => _confirmLeaveGym(gymId, gymName),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.exit_to_app,
                color: Colors.red.withValues(alpha: 0.8), size: 16),
            const SizedBox(width: 8),
            Text(
              'Leave Gym',
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.85),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLeaveGym(String gymId, String gymName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Gym?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'You will be removed from $gymName. Your active membership will be cancelled. This cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Leave', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final error = await ref.read(membershipProvider.notifier).leaveMembership(gymId);
    if (!mounted) return;
    if (error != null) {
      AppNotifications.showError(context, error);
    } else {
      await ref.read(gymAccessProvider.notifier).clearAccess();
      if (!mounted) return;
      AppNotifications.showSuccess(context, 'You have left the gym');
    }
  }

  // ─── Assigned Trainer Card ────────────────────────────────────────────────

  Widget _buildAssignedTrainerCard(GymMembershipInfo membership, String? gymId) {
    final assignmentState = ref.watch(trainerAssignmentProvider);

    // Load assignment status once when gymId is available
    if (gymId != null && assignmentState is TrainerAssignmentInitial) {
      Future.microtask(() =>
          ref.read(trainerAssignmentProvider.notifier).loadStatus(gymId));
    }

    // Don't render if loading or no trainer assigned
    if (assignmentState is! TrainerAssignmentLoaded) {
      return assignmentState is TrainerAssignmentLoading
          ? const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: AppTheme.primaryBrand,
                ),
              ),
            )
          : const SizedBox.shrink();
    }

    final loaded = assignmentState;

    // If pending request but no assigned trainer yet
    if (!loaded.hasTrainer && loaded.hasPendingRequest) {
      return _buildPendingRequestBanner(loaded.pendingRequest!, gymId!);
    }

    if (!loaded.hasTrainer) return const SizedBox.shrink();

    final trainer = loaded.assignedTrainer!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBrand.withValues(alpha: 0.12),
            AppTheme.primaryBrand.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'YOUR TRAINER',
                  style: TextStyle(
                      color: AppTheme.primaryBrand,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.primaryBrand.withValues(alpha: 0.4), width: 2),
                ),
                child: ClipOval(
                  child: (trainer.avatarUrl?.isNotEmpty == true)
                      ? CachedNetworkImage(
                          imageUrl: AppConfig.resolveMediaUrl(trainer.avatarUrl) ?? '',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.person, color: Colors.white24, size: 28),
                        )
                      : const Icon(Icons.person, color: Colors.white24, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer.fullName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    if (trainer.specialization != null)
                      Text(
                        trainer.specialization!,
                        style: const TextStyle(
                            color: AppTheme.primaryBrand,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    if (trainer.bio != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          trainer.bio!,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Fast action buttons
          Row(
            children: [
              Expanded(
                child: _trainerActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  color: AppTheme.primaryBrand,
                  onTap: gymId != null
                      ? () => _openTrainerChat(gymId, trainer, membership)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _trainerActionButton(
                  icon: Icons.fitness_center,
                  label: 'My Plan',
                  color: Colors.blue,
                  onTap: () => AppNotifications.showInfo(context, 'View your assigned plan in the Workout tab'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _trainerActionButton(
                  icon: Icons.person_remove_outlined,
                  label: 'Remove',
                  color: Colors.red.shade400,
                  onTap: gymId != null
                      ? () => _confirmRemoveTrainer(gymId)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildPendingRequestBanner(PendingRequestModel request, String gymId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request Pending',
                  style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                Text(
                  'Waiting for ${request.trainerName} to accept',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final err = await ref
                  .read(trainerAssignmentProvider.notifier)
                  .removeAssignment(gymId);
              if (err != null && mounted) {
                AppNotifications.showError(context, err);
              }
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                  color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainerActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _openTrainerChat(
      String gymId, AssignedTrainerModel trainer, GymMembershipInfo membership) async {
    AppNotifications.showInfo(context, 'Opening chat…');
    final ticket = await ref
        .read(trainerAssignmentProvider.notifier)
        .openChat(gymId, trainer.id);
    if (!mounted) return;
    if (ticket == null) {
      AppNotifications.showError(context, 'Failed to open chat');
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TrainerChatPage(
          gymId: gymId,
          trainerId: trainer.id,
          trainerName: trainer.fullName,
          trainerAvatarUrl: trainer.avatarUrl,
          trainerSpecialization: trainer.specialization,
          ticketId: ticket.id,
        ),
      ),
    );
  }

  Future<void> _confirmRemoveTrainer(String gymId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Trainer?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove your trainer assignment?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final err = await ref
        .read(trainerAssignmentProvider.notifier)
        .removeAssignment(gymId);
    if (mounted) {
      if (err != null) {
        AppNotifications.showError(context, err);
      } else {
        AppNotifications.showSuccess(context, 'Trainer removed');
      }
    }
  }

  Widget _buildTrainersSection() {
    final gymState = ref.watch(gymNotifierProvider);
    final trainers = gymState is GymLoaded ? gymState.gym.trainers : [];
    final assignmentState = ref.watch(trainerAssignmentProvider);
    final membershipState = ref.watch(membershipProvider);

    if (trainers.isEmpty) return const SizedBox.shrink();

    // Get current membership gymId for request calls
    GymMembershipInfo? currentMembership;
    if (membershipState is MembershipLoaded) {
      for (final m in membershipState.memberships) {
        if (m.isActive || m.isPending) { currentMembership = m; break; }
      }
    }
    final hasAssignedTrainer = assignmentState is TrainerAssignmentLoaded && assignmentState.hasTrainer;
    final hasPendingRequest = assignmentState is TrainerAssignmentLoaded && assignmentState.hasPendingRequest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Personal Trainers",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text("View All",
                style: TextStyle(
                    color: AppTheme.primaryBrand.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: trainers.map((trainer) => _buildTrainerCard(
              trainer,
              gymId: currentMembership?.gymId,
              showRequestButton: currentMembership != null && currentMembership.isActive
                  && !hasAssignedTrainer && !hasPendingRequest,
            )).toList(),
          ),
        )
      ],
    );
  }

  Widget _buildTrainerCard(TrainerEntity trainer, {String? gymId, bool showRequestButton = false}) {
    return GestureDetector(
      onTap: showRequestButton && gymId != null
          ? () => _showRequestTrainerDialog(gymId, trainer)
          : null,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.primaryBrand.withValues(alpha: 0.3), width: 2),
              ),
              child: ClipOval(
                child: (trainer.avatarUrl?.isNotEmpty == true)
                    ? Image(
                        image: CachedNetworkImageProvider(AppConfig.resolveMediaUrl(trainer.avatarUrl) ?? ''),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, color: Colors.white24, size: 32),
                      )
                    : const Icon(Icons.person, color: Colors.white24, size: 32),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              trainer.fullName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              trainer.specialization ?? 'General Trainer',
              style: const TextStyle(
                  color: AppTheme.primaryBrand,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showRequestButton) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Request',
                  style: TextStyle(
                      color: AppTheme.primaryBrand,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Future<void> _showRequestTrainerDialog(String gymId, TrainerEntity trainer) async {
    final msgCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Request ${trainer.fullName}',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send a request to be assigned to this trainer. They will need to accept.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: msgCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Optional message to trainer…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryBrand),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(ctx).unfocus();
              Navigator.pop(ctx, false);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBrand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              FocusScope.of(ctx).unfocus();
              Navigator.pop(ctx, true);
            },
            child: const Text('Send Request', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final err = await ref.read(trainerAssignmentProvider.notifier).requestTrainer(
          gymId, trainer.id,
          message: msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
        );
    msgCtrl.dispose();

    if (!mounted) return;
    if (err != null) {
      AppNotifications.showError(context, err);
    } else {
      AppNotifications.showSuccess(context, 'Request sent to ${trainer.fullName}!');
    }
  }

  void _comingSoon(String feature) {
    AppNotifications.showInfo(context, '$feature — coming soon');
  }

  Widget _buildGymUtilities(String? gymId) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Gym Utilities",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text("View All",
                style: TextStyle(
                    color: AppTheme.primaryBrand.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        _buildUtilityRow(Icons.local_offer, "Available Offers",
            "Exclusive member discounts",
            onTap: () => _comingSoon('Available Offers')),
        _buildUtilityRow(Icons.card_membership, "Subscription Plans",
            "Upgrade or manage plan",
            onTap: () => _comingSoon('Subscription Plans')),
        _buildUtilityRow(Icons.map, "Equipment Map",
            "Locate machines & zones",
            onTap: () => _comingSoon('Equipment Map')),
        _buildUtilityRow(Icons.construction, "Routine Builder",
            "Custom workout templates",
            onTap: () => _comingSoon('Routine Builder')),
        _buildUtilityRow(Icons.edit_note, "Log Workouts",
            "Track sets, reps & weight",
            onTap: () => _comingSoon('Log Workouts')),
        _buildUtilityRow(
          Icons.support_agent,
          "Support",
          "Report issues or ask gym staff",
          onTap: gymId != null
              ? () => _showSupportSheet(gymId)
              : () => AppNotifications.showError(context, 'No active gym membership found'),
        ),
      ],
    );
  }

  void _showSupportSheet(String gymId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => _SupportSheet(gymId: gymId),
    );
  }

  Widget _buildUtilityRow(IconData icon, String title, String subtitle,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(icon, color: AppTheme.primaryBrand, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white54)
        ],
      ),
    ),   // Container
    );   // GestureDetector
  }

  Widget _buildDaySelector() {
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final activeDay = ref.watch(activityDaySelectorProvider);
          final isActive = index == activeDay;
          return GestureDetector(
            onTap: () => ref.read(activityDaySelectorProvider.notifier).state = index,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Text(
                  days[index],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isActive ? Colors.white : Colors.white54,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: isActive ? 8 : 6,
                  height: isActive ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? AppTheme.primaryBrand
                        : Colors.transparent,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                                color: AppTheme.primaryBrand
                                    .withValues(alpha: 0.8),
                                blurRadius: 10)
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _checkCelebrationStatus() async {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _hasCelebrated = prefs.getBool('gym_welcome_celebrated') ?? false;
    });
  }

  Future<void> _markCelebrated() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('gym_welcome_celebrated', true);
    setState(() {
      _hasCelebrated = true;
    });
  }

  // ─── Upcoming Sessions ────────────────────────────────────────────────────

  Widget _buildUpcomingSessions() {
    final state = ref.watch(sessionsProvider);

    if (state.isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Upcoming Sessions'),
          const SizedBox(height: 12),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryBrand,
              ),
            ),
          ),
        ],
      );
    }

    if (state.error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Upcoming Sessions'),
          const SizedBox(height: 12),
          PremiumStateCard(
            icon: Icons.sync_problem_rounded,
            title: 'Could not load sessions',
            subtitle: state.error!,
          ),
        ],
      );
    }

    if (state.sessions.isEmpty) return const SizedBox.shrink();

    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('EEE, MMM d');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Upcoming Sessions'),
        const SizedBox(height: 12),
        ...state.sessions.map((session) {
          final typeColor = _sessionTypeColor(session.type);
          return GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => SessionBookingSheet(session: session),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: session.isBooked
                      ? AppTheme.primaryBrand.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                children: [
                  // Color bar
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${dateFormat.format(session.startTime.toLocal())}  ·  '
                          '${timeFormat.format(session.startTime.toLocal())}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right side: spots + booked badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (session.isBooked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBrand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            'Booked',
                            style: TextStyle(
                              color: AppTheme.primaryBrand,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else if (session.isFull)
                        Text(
                          'Full',
                          style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                        )
                      else if (session.maxCapacity != null)
                        Text(
                          '${session.spotsLeft} left',
                          style: TextStyle(
                            color: session.spotsLeft <= 3
                                ? Colors.orange.shade400
                                : Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 4),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Color _sessionTypeColor(String type) {
    switch (type) {
      case 'GROUP_CLASS': return Colors.blue.shade600;
      case 'ONE_ON_ONE': return AppTheme.primaryBrand;
      case 'WORKSHOP': return Colors.purple.shade500;
      default: return Colors.grey;
    }
  }

  // ─── Announcements ──────────────────────────────────────────────────────────

  Widget _buildAnnouncementsSection(String gymId) {
    final asyncAnnouncements = ref.watch(announcementsProvider(gymId));
    return asyncAnnouncements.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (announcements) {
        if (announcements.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(title: 'Announcements'),
            const SizedBox(height: 12),
            ...announcements.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildAnnouncementCard(a),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnnouncementCard(AnnouncementModel announcement) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: announcement.isPinned
            ? const Border(
                left: BorderSide(color: AppTheme.primaryBrand, width: 3),
              )
            : Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (announcement.isPinned)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_rounded,
                      size: 11, color: AppTheme.primaryBrand),
                  const SizedBox(width: 4),
                  const Text(
                    'PINNED',
                    style: TextStyle(
                      color: AppTheme.primaryBrand,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            announcement.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            announcement.body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54),
              fontSize: 13,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            _formatAnnouncementDate(announcement.publishedAt),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAnnouncementDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─── Door Access Bottom Sheet ─────────────────────────────────────────────────

class _DoorAccessSheet extends ConsumerStatefulWidget {
  final GymAccessState accessState;
  final bool isAdmitted;
  final VoidCallback onScanQr;

  const _DoorAccessSheet({
    required this.accessState,
    required this.isAdmitted,
    required this.onScanQr,
  });

  @override
  ConsumerState<_DoorAccessSheet> createState() => _DoorAccessSheetState();
}

class _DoorAccessSheetState extends ConsumerState<_DoorAccessSheet> {
  PhoneKeyStatus? _phoneKey;
  bool _enrolling = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneKeyStatus();
  }

  Future<void> _loadPhoneKeyStatus() async {
    final status = await NfcHceService.getStatus();
    if (mounted) setState(() => _phoneKey = status);
  }

  Future<void> _enrollPhone() async {
    final checkIn = widget.isAdmitted
        ? (widget.accessState as GymAccessAdmitted).checkIn
        : null;
    if (checkIn == null) return;

    final authState = ref.read(authNotifierProvider);
    if (authState is! AuthAuthenticated) return;

    setState(() => _enrolling = true);

    final userId = authState.user.id;
    final gymId = checkIn.gymId;
    final dataSource = ref.read(gymRemoteDataSourceProvider);
    final result = await NfcHceService.enroll(
      gymId: gymId,
      enrollCallback: (credHex) async {
        try {
          await dataSource.enrollPhoneKey(
            gymId: gymId,
            userId: userId,
            credentialHex: credHex,
          );
          return true;
        } catch (_) {
          return false;
        }
      },
    );

    if (!mounted) return;
    setState(() => _enrolling = false);
    if (result == HceEnrollResult.success ||
        result == HceEnrollResult.alreadyEnrolled) {
      await _loadPhoneKeyStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone NFC key activated — just tap to enter!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF2ECC71),
        ),
      );
    } else if (result == HceEnrollResult.notSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This device does not support NFC card emulation'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enrollment failed — please try again'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removePhone() async {
    final checkIn = widget.isAdmitted
        ? (widget.accessState as GymAccessAdmitted).checkIn
        : null;
    if (checkIn == null) return;

    final dataSource = ref.read(gymRemoteDataSourceProvider);
    final authState = ref.read(authNotifierProvider);
    if (authState is! AuthAuthenticated) return;

    final gymId = checkIn.gymId;
    final userId = authState.user.id;
    setState(() => _enrolling = true);
    await NfcHceService.unenroll(
      revokeCallback: (credHex) async {
        try {
          await dataSource.revokePhoneKey(
            gymId: gymId,
            userId: userId,
            credentialHex: credHex,
          );
          return true;
        } catch (_) {
          return false;
        }
      },
    );
    if (mounted) {
      setState(() => _enrolling = false);
      await _loadPhoneKeyStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final admitted = widget.isAdmitted
        ? (widget.accessState as GymAccessAdmitted)
        : null;
    final checkIn = admitted?.checkIn;
    final pk = _phoneKey;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Header
            Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2D9CDB).withValues(alpha: 0.12),
                    border: Border.all(
                        color: const Color(0xFF2D9CDB).withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.sensor_door_outlined,
                      color: Color(0xFF2D9CDB), size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Door Access',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(
                      widget.isAdmitted
                          ? 'Active session · Digital key'
                          : 'No active session',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (widget.isAdmitted && checkIn != null) ...[
              // Session info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF2D9CDB).withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.location_on_outlined, 'Gym', checkIn.gymName),
                    const SizedBox(height: 12),
                    _infoRow(Icons.login, 'Entered at', checkIn.formattedAdmittedAt),
                    const SizedBox(height: 12),
                    _infoRow(Icons.timer_outlined, 'Session until', checkIn.formattedExpiresAt),
                    if (checkIn.planName != null) ...[
                      const SizedBox(height: 12),
                      _infoRow(Icons.card_membership, 'Plan', checkIn.planName!),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // QR digital key badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D9CDB), Color(0xFF1A7CBF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF2D9CDB).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_outlined,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('QR Session Active',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${checkIn.checkInId.substring(0, 8).toUpperCase()}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 12,
                                fontFamily: 'monospace',
                                letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 10,
                      width: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF2ECC71),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0xFF2ECC71),
                              blurRadius: 6,
                              spreadRadius: 1),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Phone NFC Key section ──────────────────────────────────────
              const SizedBox(height: 16),
              _buildPhoneKeySection(pk, checkIn.gymId),
            ] else ...[
              // Not admitted state
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.lock_outline,
                        color: Colors.white.withValues(alpha: 0.3), size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Check in first to activate door access.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                          height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onScanQr,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBrand,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner, size: 18),
                            SizedBox(width: 8),
                            Text('Scan QR to Check In',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneKeySection(PhoneKeyStatus? pk, String gymId) {
    // Still loading
    if (pk == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Device doesn't support HCE at all (iOS or old Android)
    if (!pk.isSupported) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(Icons.phone_android,
                color: Colors.white.withValues(alpha: 0.25), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Phone NFC key requires Android with NFC support',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                    height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    // Enrolled & enabled — show active badge
    if (pk.isEnrolled && pk.isEnabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2B1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF2ECC71).withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                border: Border.all(
                    color: const Color(0xFF2ECC71).withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.nfc, color: Color(0xFF2ECC71), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Phone NFC Key Active',
                      style: TextStyle(
                          color: Color(0xFF2ECC71),
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  Text(
                    'Just tap your phone to any reader to enter',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        height: 1.4),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _enrolling ? null : _removePhone,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text('Remove',
                    style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    // NFC off warning
    if (!pk.isNfcOn) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.nfc, color: Colors.orange.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enable NFC in Android Settings to use your phone as a key',
                style: TextStyle(
                    color: Colors.orange.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    // Not enrolled — show enroll button
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.nfc,
                  color: Colors.white.withValues(alpha: 0.5), size: 18),
              const SizedBox(width: 8),
              Text('Phone NFC Key',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Add this phone as a keycard — tap the reader to enter without scanning QR.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _enrolling ? null : _enrollPhone,
              icon: _enrolling
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.add_card, size: 18),
              label: Text(_enrolling ? 'Activating…' : 'Add Phone as NFC Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBrand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2D9CDB), size: 16),
        const SizedBox(width: 10),
        Text('$label: ',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
        Flexible(
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─── Support Sheet ────────────────────────────────────────────────────────────

enum _SupportView { list, create, detail }

class _SupportSheet extends ConsumerStatefulWidget {
  final String gymId;
  const _SupportSheet({required this.gymId});

  @override
  ConsumerState<_SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends ConsumerState<_SupportSheet> {
  _SupportView _view = _SupportView.list;

  // Create form
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl    = TextEditingController();
  String _priority   = 'MEDIUM';
  bool _submitting   = false;

  // Reply
  final _replyCtrl   = TextEditingController();
  bool _replying     = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(supportProvider.notifier).loadTickets(widget.gymId));
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Color _statusColor(String s) {
    switch (s) {
      case 'OPEN':        return const Color(0xFF2D9CDB);
      case 'IN_PROGRESS': return const Color(0xFFF39C12);
      case 'RESOLVED':    return const Color(0xFF27AE60);
      case 'CLOSED':      return Colors.white38;
      default:            return Colors.white38;
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'URGENT': return const Color(0xFFE74C3C);
      case 'HIGH':   return const Color(0xFFF39C12);
      case 'MEDIUM': return const Color(0xFF2D9CDB);
      default:       return Colors.white38;
    }
  }

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inHours  < 1)   return '${diff.inMinutes}m ago';
    if (diff.inHours  < 24)  return '${diff.inHours}h ago';
    if (diff.inDays   < 7)   return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  // ── submit new ticket ────────────────────────────────────────────────────

  Future<void> _submitTicket() async {
    if (_subjectCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final ok = await ref.read(supportProvider.notifier).createTicket(
      gymId:    widget.gymId,
      subject:  _subjectCtrl.text.trim(),
      body:     _bodyCtrl.text.trim(),
      priority: _priority,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      _subjectCtrl.clear();
      _bodyCtrl.clear();
      _priority = 'MEDIUM';
      setState(() => _view = _SupportView.list);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create ticket. Try again.')),
      );
    }
  }

  // ── send reply ───────────────────────────────────────────────────────────

  Future<void> _sendReply(String ticketId) async {
    if (_replyCtrl.text.trim().isEmpty) return;
    setState(() => _replying = true);
    final ok = await ref.read(supportProvider.notifier).reply(
      gymId:    widget.gymId,
      ticketId: ticketId,
      body:     _replyCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _replying = false);
    if (ok) {
      _replyCtrl.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send reply. Try again.')),
      );
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final supportState = ref.watch(supportProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.modalBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.modalRadius)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.modalRadius)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: AppTheme.modalBlur, sigmaY: AppTheme.modalBlur),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: AppTheme.modalHandleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // header
              _buildHeader(supportState),
              const Divider(color: Colors.white12, height: 1),
              // body
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.72,
                  ),
                  child: _buildBody(supportState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(SupportState state) {
    String title = 'Support Tickets';
    if (_view == _SupportView.create) title = 'New Ticket';
    if (_view == _SupportView.detail && state is SupportDetailLoaded) {
      title = state.detail.subject;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          if (_view != _SupportView.list)
            IconButton(
              onPressed: () {
                if (_view == _SupportView.detail) {
                  ref.read(supportProvider.notifier).backToList();
                }
                setState(() => _view = _SupportView.list);
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (_view != _SupportView.list) const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_view != _SupportView.list) const SizedBox(width: 48), // Balance for arrow
          if (_view == _SupportView.list)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white70),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (_view == _SupportView.list)
            GestureDetector(
              onTap: () => setState(() => _view = _SupportView.create),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: AppTheme.primaryBrand, size: 14),
                    const SizedBox(width: 4),
                    Text('New', style: TextStyle(color: AppTheme.primaryBrand, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── body router ───────────────────────────────────────────────────────────

  Widget _buildBody(SupportState state) {
    if (_view == _SupportView.create) return _buildCreateView();
    if (_view == _SupportView.detail && state is SupportDetailLoaded) {
      return _buildDetailView(state.detail);
    }
    return _buildListView(state);
  }

  // ── list view ─────────────────────────────────────────────────────────────

  Widget _buildListView(SupportState state) {
    if (state is SupportLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryBrand, strokeWidth: 2)),
      );
    }
    if (state is SupportError) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumStateCard(
          icon: Icons.error_outline_rounded,
          title: 'Connection Error',
          subtitle: state.message,
          onAction: () => ref.read(supportProvider.notifier).loadTickets(widget.gymId),
          actionLabel: 'Retry',
        ),
      );
    }

    final tickets = state is SupportLoaded
        ? state.tickets
        : state is SupportDetailLoaded
            ? state.tickets
            : <SupportTicketModel>[];

    if (tickets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: const PremiumStateCard(
          icon: Icons.support_agent_rounded,
          title: 'No tickets yet',
          subtitle: 'Reach out to gym support by tapping "New" above.',
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildTicketTile(tickets[i]),
    );
  }

  Widget _buildTicketTile(SupportTicketModel ticket) {
    return GestureDetector(
      onTap: () async {
        await ref.read(supportProvider.notifier).loadDetail(widget.gymId, ticket.id);
        if (mounted) setState(() => _view = _SupportView.detail);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _pillBadge(ticket.status.replaceAll('_', ' '), _statusColor(ticket.status)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _pillBadge(ticket.priority, _priorityColor(ticket.priority)),
                const SizedBox(width: 8),
                Icon(Icons.chat_bubble_outline, size: 12, color: Colors.white.withValues(alpha: 0.35)),
                const SizedBox(width: 4),
                Text(
                  '${ticket.messageCount}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _fmtDate(ticket.updatedAt),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── create view ───────────────────────────────────────────────────────────

  Widget _buildCreateView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Subject'),
          const SizedBox(height: 6),
          _textField(_subjectCtrl, 'Brief description of your issue', maxLines: 1),
          const SizedBox(height: 16),
          _fieldLabel('Description'),
          const SizedBox(height: 6),
          _textField(_bodyCtrl, 'Describe your issue in detail…', maxLines: 5),
          const SizedBox(height: 16),
          _fieldLabel('Priority'),
          const SizedBox(height: 8),
          _buildPriorityPicker(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBrand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Submit Ticket', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityPicker() {
    const options = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];
    return Row(
      children: options.map((p) {
        final selected = _priority == p;
        final color = _priorityColor(p);
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _priority = p),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? color : Colors.white.withValues(alpha: 0.1),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  p,
                  style: TextStyle(
                    color: selected ? color : Colors.white38,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── detail view ───────────────────────────────────────────────────────────

  Widget _buildDetailView(SupportTicketModel ticket) {
    final messages = ticket.messages;

    return Column(
      children: [
        // status bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _pillBadge(ticket.status.replaceAll('_', ' '), _statusColor(ticket.status)),
              const SizedBox(width: 8),
              _pillBadge(ticket.priority, _priorityColor(ticket.priority)),
              const Spacer(),
              Text(
                'Opened ${_fmtDate(ticket.createdAt)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        // message thread
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _buildMessageBubble(messages[i]),
                ),
        ),
        // reply bar (only if not closed)
        if (ticket.status != 'CLOSED') _buildReplyBar(ticket.id),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMessageBubble(TicketMessageModel msg) {
    final isStaff = msg.isStaff;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isStaff ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isStaff) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryBrand.withValues(alpha: 0.2),
              backgroundImage: msg.senderAvatarUrl != null
                  ? CachedNetworkImageProvider(AppConfig.resolveMediaUrl(msg.senderAvatarUrl) ?? '')
                  : null,
              child: msg.senderAvatarUrl == null
                  ? Icon(Icons.support_agent, color: AppTheme.primaryBrand, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isStaff ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isStaff ? msg.senderName : 'You',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _fmtDate(msg.createdAt),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isStaff
                        ? AppTheme.primaryBrand.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(14),
                      topRight:    const Radius.circular(14),
                      bottomLeft:  Radius.circular(isStaff ? 4 : 14),
                      bottomRight: Radius.circular(isStaff ? 14 : 4),
                    ),
                    border: Border.all(
                      color: isStaff
                          ? AppTheme.primaryBrand.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    msg.body,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          if (!isStaff) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildReplyBar(String ticketId) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: null,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Write a reply…',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _replying ? null : () => _sendReply(ticketId),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBrand,
                shape: BoxShape.circle,
              ),
              child: _replying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.black, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── shared helpers ────────────────────────────────────────────────────────

  Widget _pillBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
      );

  Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryBrand.withValues(alpha: 0.6)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _CloudSyncIndicator extends ConsumerWidget {
  const _CloudSyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(profileSyncProvider);
    if (!syncState.isSyncing) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryBrand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBrand.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryBrand.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Syncing...',
            style: TextStyle(
              color: AppTheme.primaryBrand.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ).animate(onPlay: (controller) => controller.repeat())
       .shimmer(duration: 1500.ms, color: Colors.white24),
    );
  }

}
