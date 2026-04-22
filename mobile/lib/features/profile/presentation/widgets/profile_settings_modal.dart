import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:amirani_app/theme/app_theme.dart';
import '../providers/profile_sync_provider.dart';
import '../../../gym/presentation/providers/gym_provider.dart';
import '../../../gym/domain/entities/registration_requirements_entity.dart';
import '../../../../core/providers/diet_profile_sync_provider.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/providers/workout_profile_sync_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/utils/error_messages.dart';
import 'package:amirani_app/core/localization/l10n_provider.dart';
import 'package:amirani_app/core/localization/l10n_state.dart';
import 'package:amirani_app/core/localization/language_flag.dart';

class ProfileSettingsModal extends ConsumerStatefulWidget {
  const ProfileSettingsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => const ProfileSettingsModal(),
    );
  }

  @override
  ConsumerState<ProfileSettingsModal> createState() =>
      _ProfileSettingsModalState();
}

class _ProfileSettingsModalState extends ConsumerState<ProfileSettingsModal> {
  XFile? _profileImage;
  XFile? _idImage;
  String _dob = '1990-01-01';
  String _gender = 'Male';
  bool _noMedicalConditions = false;
  bool _isInitialized = false;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _targetWeightController;
  late TextEditingController _medicalController;
  late TextEditingController _phoneController;
  late TextEditingController _personalNumberController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _targetWeightController = TextEditingController();
    _medicalController = TextEditingController();
    _phoneController = TextEditingController();
    _personalNumberController = TextEditingController();
    _addressController = TextEditingController();

    _firstNameController.addListener(() {
      setState(() {});
    });
    _lastNameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _targetWeightController.dispose();
    _medicalController.dispose();
    _phoneController.dispose();
    _personalNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(profileSyncProvider);

    if (!_isInitialized && syncState.isInitialized) {
      _firstNameController.text = syncState.firstName;
      _lastNameController.text = syncState.lastName;
      _weightController.text = syncState.weight;
      _heightController.text = syncState.height;
      _targetWeightController.text =
          syncState.targetWeightKg?.toStringAsFixed(1) ?? '';
      _medicalController.text = syncState.medicalConditions;
      _phoneController.text = syncState.phoneNumber;
      _personalNumberController.text = syncState.personalNumber;
      _addressController.text = syncState.address;
      _dob = syncState.dob.isEmpty ? '1990-01-01' : syncState.dob;
      
      // Normalize gender to ensure it's in ['Male', 'Female', 'Other']
      final rawGender = syncState.gender.trim();
      if (rawGender.toLowerCase() == 'male') {
        _gender = 'Male';
      } else if (rawGender.toLowerCase() == 'female') {
        _gender = 'Female';
      } else if (rawGender.toLowerCase() == 'other') {
        _gender = 'Other';
      } else {
        _gender = 'Male'; 
      }
      
      _noMedicalConditions = syncState.noMedicalConditions;
      if (syncState.profileImagePath != null) {
        _profileImage = XFile(syncState.profileImagePath!);
      }
      if (syncState.idImagePath != null) {
        _idImage = XFile(syncState.idImagePath!);
      }
      
      // Only mark as fully initialized if we actually have some data or it's definitely the final state
      if (syncState.firstName.isNotEmpty || syncState.lastName.isNotEmpty || !syncState.isSyncing) {
        _isInitialized = true;
      }
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    final gymState = ref.watch(gymNotifierProvider);
    final regReqs =
        (gymState is GymLoaded) ? gymState.gym.registrationRequirements : null;

    // Keep sync providers alive so their listeners fire when profile saves
    ref.watch(dietProfileSyncProvider);
    ref.watch(workoutProfileSyncProvider);

    return Container(
      height: screenHeight * 0.85 + bottomInset,
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
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.modalRadius)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: AppTheme.modalBlur, sigmaY: AppTheme.modalBlur),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Personal Info',
                          style: TextStyle(
                              color: AppTheme.primaryBrand,
                              fontWeight: FontWeight.bold)),
                    ),
                    _buildTextField('First Name', 'Enter first name',
                        controller: _firstNameController),
                    const SizedBox(height: 16),
                    _buildTextField('Last Name', 'Enter last name',
                        controller: _lastNameController),
                    const SizedBox(height: 16),
                    _buildDropdown(
                        'Gender', ['Male', 'Female', 'Other'], _gender,
                        onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _gender = value;
                        });
                      }
                    }),
                    const SizedBox(height: 16),
                    _buildTextField('Date of Birth', _dob,
                        icon: Icons.calendar_today,
                        readOnly: true, onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(_dob) ?? DateTime(1990),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppTheme.primaryBrand,
                                onPrimary: Colors.black,
                                surface: AppTheme.surfaceDark,
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() {
                          _dob =
                              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                        });
                      }
                    }),
                    if (regReqs?.phoneNumber == true) ...[
                      const SizedBox(height: 16),
                      _buildTextField('Phone Number', 'e.g., +1 234 567 8900',
                          controller: _phoneController, isNumber: true),
                    ],
                    if (regReqs?.personalNumber == true) ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                          'Personal / ID Number', 'Enter your ID number',
                          controller: _personalNumberController),
                    ],
                    if (regReqs?.address == true) ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                          'Home Address', 'Full residential address',
                          controller: _addressController),
                    ],
                    if (regReqs?.idPhoto == true) ...[
                      const SizedBox(height: 16),
                      _buildIDUploadButton(),
                    ],
                    const SizedBox(height: 32),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Medical & Health',
                          style: TextStyle(
                              color: AppTheme.primaryBrand,
                              fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBrand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryBrand),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.health_and_safety,
                              color: AppTheme.primaryBrand),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Mandatory for AI features. Policy synchronized with Branch requirements.',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField('Weight (kg)', 'e.g., 75',
                                isNumber: true, controller: _weightController)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildTextField('Height (cm)', 'e.g., 180',
                                isNumber: true, controller: _heightController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Goal Weight (kg)',
                      'e.g., 70',
                      isNumber: true,
                      controller: _targetWeightController,
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _noMedicalConditions = !_noMedicalConditions;
                          if (_noMedicalConditions) {
                            _medicalController.clear();
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            height: 24,
                            width: 24,
                            decoration: BoxDecoration(
                              color: _noMedicalConditions
                                  ? AppTheme.primaryBrand
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _noMedicalConditions
                                    ? AppTheme.primaryBrand
                                    : Colors.white54,
                                width: 2,
                              ),
                            ),
                            child: _noMedicalConditions
                                ? const Icon(Icons.check,
                                    color: AppTheme.backgroundDark, size: 16)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "I don't have any medical conditions or allergies",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: _noMedicalConditions ? 0.4 : 1.0,
                      child: IgnorePointer(
                        ignoring: _noMedicalConditions,
                        child: _buildTextField('Medical Conditions',
                            'Type any allergies, chronic diseases, or dietary restrictions here...',
                            maxLines: 4, controller: _medicalController),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              _buildAccountActions(),
              _buildSaveButton(regReqs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountActions() {
    final l10n = ref.watch(l10nProvider);
    final hasLang = l10n.hasAlternative || l10n.isDownloading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // ── Language switcher (visible when an alt language is available) ──
          if (hasLang) ...[
            _LanguageSwitcherRow(l10n: l10n, ref: ref),
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 12),
          ],
          // ── Sign Out / Delete Account ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AccountActionButton(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                onTap: _confirmSignOut,
              ),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white12,
              ),
              _AccountActionButton(
                icon: Icons.delete_outline_rounded,
                label: 'Delete Account',
                onTap: _confirmDeleteAccount,
                dimmer: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will be returned to the login screen.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      FocusScope.of(context).unfocus();
      Navigator.pop(context); // close modal first
      ref.read(authNotifierProvider.notifier).logout();
    }
  }


  Future<void> _confirmDeleteAccount() async {
    // Step 1: warn with strong language
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Account?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete your account and all associated data. This cannot be undone.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    // Step 2: type-to-confirm
    final confirmCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Are you sure?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type DELETE to confirm:', style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red.shade800.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red.shade600),
                  borderRadius: BorderRadius.circular(10),
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
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          StatefulBuilder(
            builder: (_, setState) => ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
              onPressed: () {
                if (confirmCtrl.text.trim() == 'DELETE') {
                  FocusScope.of(ctx).unfocus();
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Delete My Account'),
            ),
          ),
        ],
      ),
    );
    confirmCtrl.dispose();
    if (confirmed != true || !mounted) return;

    // Step 3: call API then logout
    try {
      await ref.read(dioProvider).delete('/users/me');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMessages.from(e, fallback: 'Failed to delete account. Please try again.'))),
      );
      return;
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    Navigator.pop(context);
    ref.read(authNotifierProvider.notifier).logout();
  }

  ImageProvider? _getImageProvider(XFile? file, String? remotePath) {
    if (file != null) {
      if (file.path.startsWith('http')) {
        return CachedNetworkImageProvider(file.path);
      }
      return FileImage(File(file.path));
    }
    if (remotePath != null && remotePath.isNotEmpty) {
      return CachedNetworkImageProvider(AppConfig.resolveMediaUrl(remotePath) ?? '');
    }
    return null;
  }

  Widget _buildIDUploadButton() {
    final syncState = ref.watch(profileSyncProvider);
    final idProvider = _getImageProvider(_idImage, syncState.idImagePath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ID / Passport Photo',
          style: TextStyle(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final ImagePicker picker = ImagePicker();
            final XFile? image =
                await picker.pickImage(source: ImageSource.camera);
            if (image != null) {
              setState(() {
                _idImage = image;
              });
            }
          },
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              image: idProvider != null
                  ? DecorationImage(
                      image: idProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: idProvider == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge, color: Colors.white54, size: 32),
                        SizedBox(height: 8),
                        Text('Tap to upload ID',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      height: 4,
      width: 40,
      decoration: BoxDecoration(
        color: AppTheme.modalHandleColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    final syncState = ref.watch(profileSyncProvider);
    final profileProvider = _getImageProvider(_profileImage, syncState.profileImagePath);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? image =
                  await picker.pickImage(source: ImageSource.camera);
              if (image != null) {
                setState(() {
                  _profileImage = image;
                });
              }
            },
            child: Container(
              height: 56, // Slightly reduced to fit consistent header
              width: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryBrand, width: 2),
                color: AppTheme.surfaceDark,
                image: profileProvider != null
                    ? DecorationImage(
                        image: profileProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (profileProvider == null)
                    const Center(
                      child: Icon(Icons.person, color: Colors.white24, size: 28),
                    ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.backgroundDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_firstNameController.text} ${_lastNameController.text}'
                          .trim()
                          .isEmpty
                      ? 'Your Name'
                      : '${_firstNameController.text} ${_lastNameController.text}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20, // Consistent with other modals
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Branch Connection Active',
                  style: TextStyle(color: AppTheme.primaryBrand.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String placeholder,
      {bool isNumber = false,
      int maxLines = 1,
      IconData? icon,
      bool readOnly = false,
      VoidCallback? onTap,
      TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: Colors.white24),
            suffixIcon: icon != null
                ? Icon(icon, color: Colors.white54, size: 20)
                : null,
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.3),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppTheme.primaryBrand,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value,
      {ValueChanged<String?>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: AppTheme.surfaceDark,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: items.contains(value) ? value : items.first,
                dropdownColor: const Color(
                    0xFF1E1E1E), // Slightly elevated from pure black, but dark
                borderRadius: BorderRadius.circular(16),
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: Colors.white54),
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: TextStyle(
                        color: item == (items.contains(value) ? value : items.first)
                            ? AppTheme.primaryBrand
                            : Colors.white,
                        fontWeight:
                            item == (items.contains(value) ? value : items.first) ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
                // Keep the displayed text white in the closed state
                selectedItemBuilder: (BuildContext context) {
                  return items.map((String item) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList();
                },
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(RegistrationRequirementsEntity? regReqs) {
    final isSyncing = ref.watch(profileSyncProvider.select((s) => s.isSyncing));
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: ElevatedButton(
        onPressed: isSyncing ? null : () {
          FocusScope.of(context).unfocus();
          HapticFeedback.mediumImpact();
          final targetWt =
              double.tryParse(_targetWeightController.text.trim());
          ref.read(profileSyncProvider.notifier).saveProfile(
                firstName: _firstNameController.text,
                lastName: _lastNameController.text,
                weight: _weightController.text,
                height: _heightController.text,
                medicalConditions: _medicalController.text,
                dob: _dob,
                gender: _gender,
                noMedicalConditions: _noMedicalConditions,
                phoneNumber: _phoneController.text,
                personalNumber: _personalNumberController.text,
                address: _addressController.text,
                profileImagePath: _profileImage?.path,
                idImagePath: _idImage?.path,
                targetWeightKg: targetWt,
                policy: regReqs,
              );
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBrand,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isSyncing
            ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Text(
                'Save Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
      ),
    );
  }
}

/// Compact EN ↔ alt language row shown above the account action buttons.
/// Hidden automatically when no alternative language is configured.
class _LanguageSwitcherRow extends StatelessWidget {
  final L10nState l10n;
  final WidgetRef ref;

  const _LanguageSwitcherRow({required this.l10n, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          const Icon(Icons.language_rounded, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Text(
            'Language',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
        if (l10n.isDownloading)
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBrand),
            ),
          )
        else
          _LangPill(
            isEnglish: l10n.isEnglish,
            altCode:   l10n.altLangCode ?? l10n.lang,
            onToggle:  (toEnglish) {
              HapticFeedback.lightImpact();
              ref.read(l10nProvider.notifier).switchTo(
                toEnglish ? 'en' : (l10n.altLangCode ?? l10n.lang),
              );
            },
          ),
      ],
    );
  }
}

/// Animated flag pill used inside [_LanguageSwitcherRow].
class _LangPill extends StatelessWidget {
  final bool isEnglish;
  final String altCode;  // language code e.g. 'ka'
  final void Function(bool toEnglish) onToggle;

  const _LangPill({
    required this.isEnglish,
    required this.altCode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!isEnglish),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _LangChip(langCode: 'en',    active: isEnglish),
          const SizedBox(width: 2),
          _LangChip(langCode: altCode, active: !isEnglish),
        ]),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String langCode;
  final bool active;
  const _LangChip({required this.langCode, required this.active});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeInOut,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: active ? AppTheme.primaryBrand : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      LanguageFlag.of(langCode),
      style: const TextStyle(fontSize: 18, height: 1.2),
    ),
  );
}

class _AccountActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dimmer;

  const _AccountActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = dimmer ? Colors.red.withValues(alpha: 0.5) : Colors.red;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
