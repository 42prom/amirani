import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/storage_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../data/datasources/profile_local_data_source.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../../gym/presentation/providers/gym_provider.dart';
import '../../../gym/domain/entities/registration_requirements_entity.dart';
import '../../../../core/data/local_db_service.dart';
import '../../../../core/network/dio_provider.dart';

final profileRemoteDataSourceProvider =
    Provider<ProfileRemoteDataSource>((ref) {
  return ProfileRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

final profileLocalDataSourceProvider = Provider<ProfileLocalDataSource>((ref) {
  return ProfileLocalDataSourceImpl(profileBox: LocalDBService.profileBox);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(
      remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
      localDataSource: ref.watch(profileLocalDataSourceProvider),
  );
});

final profileSyncProvider =
    StateNotifierProvider<ProfileSyncNotifier, ProfileSyncState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final notifier = ProfileSyncNotifier(repository, ref);

  // Reactively sync with gym rules
  ref.listen(gymNotifierProvider, (previous, next) {
    if (next is GymLoaded) {
      notifier.validateWithPolicy(next.gym.registrationRequirements);
    }
  }, fireImmediately: true);

  // Authenticated? Refresh profile data from backend
  ref.listen(authNotifierProvider, (previous, next) {
    if (next is AuthAuthenticated) {
      notifier.loadProfileStatus();
    }
  });

  return notifier;
});

class ProfileSyncState {
  final bool hasPersonalData;
  final bool hasMedicalData;
  final bool isSyncing;
  final bool isInitialized;

  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String weight;
  final String height;
  final String medicalConditions;
  final String dob;
  final String gender;
  final bool noMedicalConditions;
  final String phoneNumber;
  final String personalNumber;
  final String address;
  final String? profileImagePath;
  final String? idImagePath;
  final double? targetWeightKg;

  const ProfileSyncState({
    this.hasPersonalData = false,
    this.hasMedicalData = false,
    this.email = '',
    this.firstName = '',
    this.lastName = '',
    this.fullName = '',
    this.weight = '',
    this.height = '',
    this.medicalConditions = '',
    this.dob = '',
    this.gender = '',
    this.noMedicalConditions = false,
    this.phoneNumber = '',
    this.personalNumber = '',
    this.address = '',
    this.profileImagePath,
    this.idImagePath,
    this.targetWeightKg,
    this.isSyncing = false,
    this.isInitialized = false,
  });

  ProfileSyncState copyWith({
    bool? hasPersonalData,
    bool? hasMedicalData,
    String? email,
    String? firstName,
    String? lastName,
    String? fullName,
    String? weight,
    String? height,
    String? medicalConditions,
    String? dob,
    String? gender,
    bool? noMedicalConditions,
    String? phoneNumber,
    String? personalNumber,
    String? address,
    String? profileImagePath,
    String? idImagePath,
    double? targetWeightKg,
    bool? isSyncing,
    bool? isInitialized,
  }) {
    return ProfileSyncState(
      hasPersonalData: hasPersonalData ?? this.hasPersonalData,
      hasMedicalData: hasMedicalData ?? this.hasMedicalData,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      noMedicalConditions: noMedicalConditions ?? this.noMedicalConditions,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      personalNumber: personalNumber ?? this.personalNumber,
      address: address ?? this.address,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      idImagePath: idImagePath ?? this.idImagePath,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      isSyncing: isSyncing ?? this.isSyncing,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class ProfileSyncNotifier extends StateNotifier<ProfileSyncState> {
  final ProfileRepository _repository;
  final Ref _ref;

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialized => _initCompleter.future;

  ProfileSyncNotifier(this._repository, this._ref) : super(const ProfileSyncState()) {
    _init();
  }

  Future<void> _init() async {
    // 1. Try loading from local cache instantly
    final cached = await _repository.getCachedProfile();
    cached.fold(
      (failure) => null,
      (user) {
        if (user != null) {
          _updateStateFromUser(user);
        }
      },
    );

    state = state.copyWith(isInitialized: true);
    if (!_initCompleter.isCompleted) _initCompleter.complete();

    // 2. Trigger network refresh if authenticated
    final auth = _ref.read(authNotifierProvider);
    if (auth is AuthAuthenticated) {
      loadProfileStatus();
    }
  }

  // Fetch profile from backend to hydrate state
  Future<void> loadProfileStatus() async {
    state = state.copyWith(isSyncing: true);
    final result = await _repository.getLatestProfile();
    state = state.copyWith(isSyncing: false);
    result.fold(
      (failure) => null, // Handle error if needed
      (user) {
        if (user != null) {
          _updateStateFromUser(user);
        }
      },
    );
  }

  /// Update state from a raw JSON user object (received from sync)
  void updateFromSync(Map<String, dynamic> userData) {
    final processed = Map<String, dynamic>.from(userData);
    // DB stores targetWeightKg as String; coerce to double for UserEntity.
    if (processed['targetWeightKg'] is String) {
      processed['targetWeightKg'] =
          double.tryParse(processed['targetWeightKg'] as String);
    }
    _updateStateFromUser(UserEntity.fromJson(processed));
  }

  void _updateStateFromUser(UserEntity user) {
    // Defensive: Treat empty strings as "no data" to avoid overwriting valid local state
    String? clean(String? s) => (s != null && s.trim().isNotEmpty) ? s : null;

    String? fName = clean(user.firstName);
    String? lName = clean(user.lastName);
    final fFull = clean(user.fullName);

    // If firstName/lastName are missing but fullName exists, attempt to split it
    if (fName == null && fFull != null) {
      final parts = fFull.split(' ');
      if (parts.isNotEmpty) {
        fName = parts[0];
        if (lName == null && parts.length > 1) {
          lName = parts.skip(1).join(' ');
        }
      }
    }

    // Unified Merge: Only use incoming if it has data. Otherwise, keep current state.
    final mCond = clean(user.medicalConditions);
    final noMed = user.noMedicalConditions;
    bool hasHealthMsg = mCond != null || noMed == true;

    state = state.copyWith(
      email: clean(user.email) ?? state.email,
      firstName: fName ?? state.firstName,
      lastName: lName ?? state.lastName,
      fullName: fFull ?? state.fullName,
      dob: clean(user.dob) ?? state.dob,
      gender: clean(user.gender) ?? state.gender,
      weight: clean(user.weight) ?? state.weight,
      height: clean(user.height) ?? state.height,
      phoneNumber: clean(user.phoneNumber) ?? state.phoneNumber,
      personalNumber: clean(user.personalNumber) ?? state.personalNumber,
      address: clean(user.address) ?? state.address,
      medicalConditions: hasHealthMsg ? (noMed ? '' : (mCond ?? '')) : state.medicalConditions,
      noMedicalConditions: hasHealthMsg ? noMed : state.noMedicalConditions,
      targetWeightKg: user.targetWeightKg ?? state.targetWeightKg,
      profileImagePath: user.avatarUrl ?? state.profileImagePath,
      idImagePath: user.idPhotoUrl ?? state.idImagePath,
    );

    // After updating from remote, validate against current gym rules
    final gymState = _ref.read(gymNotifierProvider);
    if (gymState is GymLoaded) {
      validateWithPolicy(gymState.gym.registrationRequirements);
    }
  }

  Future<void> saveProfile({
    String? firstName,
    String? lastName,
    String? weight,
    String? height,
    String? medicalConditions,
    String? dob,
    String? gender,
    bool? noMedicalConditions,
    String? phoneNumber,
    String? personalNumber,
    String? address,
    String? profileImagePath,
    String? idImagePath,
    double? targetWeightKg,
    RegistrationRequirementsEntity? policy,
  }) async {
    // Current or new values
    final currentPhone = phoneNumber ?? state.phoneNumber;
    final currentPersonal = personalNumber ?? state.personalNumber;
    final currentAddress = address ?? state.address;
    final currentId = idImagePath ?? state.idImagePath;
    final currentMedical = medicalConditions ?? state.medicalConditions;
    final currentNoMed = noMedicalConditions ?? state.noMedicalConditions;

    bool isPersonalValid = true;
    bool isMedicalValid = true;

    if (policy != null) {
      if (policy.phoneNumber && currentPhone.isEmpty) {
        isPersonalValid = false;
      }
      if (policy.personalNumber && currentPersonal.isEmpty) {
        isPersonalValid = false;
      }
      if (policy.address && currentAddress.isEmpty) {
        isPersonalValid = false;
      }
      if (policy.idPhoto && currentId == null) {
        isPersonalValid = false;
      }

      if (policy.healthInfo && currentMedical.isEmpty && !currentNoMed) {
        isMedicalValid = false;
      }
    }

    final newState = state.copyWith(
      hasPersonalData: isPersonalValid,
      hasMedicalData: isMedicalValid,
      firstName: firstName ?? state.firstName,
      lastName: lastName ?? state.lastName,
      weight: weight ?? state.weight,
      height: height ?? state.height,
      medicalConditions: currentMedical,
      dob: dob ?? state.dob,
      gender: gender ?? state.gender,
      noMedicalConditions: currentNoMed,
      phoneNumber: currentPhone,
      personalNumber: currentPersonal,
      address: currentAddress,
      profileImagePath: profileImagePath ?? state.profileImagePath,
      idImagePath: currentId,
      targetWeightKg: targetWeightKg ?? state.targetWeightKg,
    );

    state = newState.copyWith(isSyncing: true);

    // 1. Upload images if they are local paths
    String? finalProfilePath = newState.profileImagePath;
    String? finalIdPath = newState.idImagePath;

    if (finalProfilePath != null && !finalProfilePath.startsWith('http')) {
      try {
        finalProfilePath = await _uploadFile(File(finalProfilePath), 'avatars');
      } catch (e) {
        // Fall back to current if upload fails
        finalProfilePath = state.profileImagePath;
      }
    }

    if (finalIdPath != null && !finalIdPath.startsWith('http')) {
      try {
        finalIdPath = await _uploadFile(File(finalIdPath), 'gyms');
      } catch (e) {
        // Fall back to current if upload fails
        finalIdPath = state.idImagePath;
      }
    }

    // 2. Normalize URLs (strip full domain if it's already there from sync down)
    String normalize(String? path) {
        if (path == null) return '';
        if (path.contains('/uploads/')) {
          return '/uploads/${path.split('/uploads/').last}';
        }
        return path;
    }
 
    // Safety: Don't sync effectively "empty" names if we are just applying onboarding data
    // and initialization might have just finished but was empty.
    if (newState.firstName.isEmpty && newState.lastName.isEmpty) {
      final currentResult = await _repository.getCachedProfile();
      bool shouldAbort = false;
      currentResult.fold((_) => null, (user) {
        if (user != null && (user.firstName?.isNotEmpty == true || user.lastName?.isNotEmpty == true)) {
           shouldAbort = true;
        }
      });
      if (shouldAbort) {
        state = state.copyWith(isSyncing: false);
        return;
      }
    }

    // Persist to backend and local cache
    await _repository.syncProfile(UserEntity(
      id: '', // Backend uses authenticated userId
      email: '', // Backend uses authenticated email
      role: '', // Backend doesn't update role here
      firstName: newState.firstName.isNotEmpty ? newState.firstName : null,
      lastName: newState.lastName.isNotEmpty ? newState.lastName : null,
      fullName: '${newState.firstName} ${newState.lastName}'.trim(),
      phoneNumber: newState.phoneNumber.isNotEmpty ? newState.phoneNumber : null,
      gender: newState.gender.isNotEmpty ? newState.gender : null,
      dob: newState.dob.isNotEmpty ? newState.dob : null,
      weight: newState.weight.isNotEmpty ? newState.weight : null,
      height: newState.height.isNotEmpty ? newState.height : null,
      medicalConditions: newState.medicalConditions.isNotEmpty ? newState.medicalConditions : null,
      noMedicalConditions: newState.noMedicalConditions,
      personalNumber: newState.personalNumber.isNotEmpty ? newState.personalNumber : null,
      address: newState.address.isNotEmpty ? newState.address : null,
      avatarUrl: normalize(finalProfilePath),
      idPhotoUrl: normalize(finalIdPath),
      targetWeightKg: newState.targetWeightKg,
    ));
    state = state.copyWith(
      isSyncing: false,
      profileImagePath: finalProfilePath,
      idImagePath: finalIdPath,
    );
  }

  /// Update medical conditions text
  void updateMedicalConditions(String conditions) {
    state = state.copyWith(
      medicalConditions: conditions,
      noMedicalConditions: false,
    );
    // Persist to backend
    saveProfile(medicalConditions: conditions, noMedicalConditions: false).catchError((Object e) { debugPrint('[ProfileSync] background save failed: $e'); return null; });
  }

  /// Called once after auth — reads onboarding data from SharedPreferences
  /// and pushes it to the backend profile, then clears the pending keys.
  Future<void> applyPendingOnboardingData() async {
    // Wait for Hive cache to be loaded first so we don't overwrite real names with ''
    await initialized;

    final prefs = _ref.read(sharedPreferencesProvider);
    final gender = prefs.getString('ob_gender') ?? '';
    final heightCm = prefs.getDouble('ob_height_cm');
    final dob = prefs.getString('ob_dob') ?? '';
    final weightKg = prefs.getDouble('ob_weight_kg');
    final targetWeightKg = prefs.getDouble('ob_target_weight_kg');
    final conditions = prefs.getString('ob_health_conditions') ?? '';
    final noConditions = prefs.getBool('ob_no_health_conditions') ?? false;

    // Nothing stored — onboarding data was never collected or already applied
    if (gender.isEmpty && heightCm == null && weightKg == null && dob.isEmpty) return;

    await saveProfile(
      gender: gender.isNotEmpty ? _capitalise(gender) : null,
      height: heightCm?.toStringAsFixed(1),
      dob: dob.isNotEmpty ? dob.split('T')[0] : null,
      weight: weightKg?.toStringAsFixed(1),
      medicalConditions: conditions.isNotEmpty ? conditions : null,
      noMedicalConditions: noConditions,
      targetWeightKg: targetWeightKg,
    );

    // After updating backend, ensure AuthProvider's user entity is updated too
    await _ref.read(authNotifierProvider.notifier).refreshProfile();

    // Clear pending keys so this only runs once
    for (final key in [
      'ob_gender', 'ob_height_cm', 'ob_dob', 'ob_weight_kg',
      'ob_target_weight_kg', 'ob_health_conditions', 'ob_no_health_conditions',
    ]) {
      prefs.remove(key);
    }

    // Fire-and-forget: trigger AI plan generation (BOTH workout + diet) with fresh metrics.
    // type=BOTH skips the diet-plan-required guard — it's the first-time setup flow.
    try {
      int? ageYears;
      final dobDate = DateTime.tryParse(dob);
      if (dobDate != null) {
        final now = DateTime.now();
        ageYears = now.year - dobDate.year;
        if (now.month < dobDate.month || (now.month == dobDate.month && now.day < dobDate.day)) {
          ageYears--;
        }
      }

      final dio = _ref.read(dioProvider);
      await dio.post('/sync/ai/generate-plan', data: {
        'type': 'BOTH',
        'goals': 'general_fitness',
        'fitnessLevel': 'BEGINNER',
        'daysPerWeek': 4,
        'userMetrics': {
          if (weightKg != null) 'weightKg': weightKg,
          if (heightCm != null) 'heightCm': heightCm,
          if (ageYears != null) 'age': ageYears,
          if (gender.isNotEmpty) 'gender': gender,
        },
      });
    } catch (_) {
      // Non-blocking — user can manually generate plans from their profile
    }
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Update no medical conditions flag
  void updateNoMedicalConditions(bool value) {
    state = state.copyWith(
      noMedicalConditions: value,
      medicalConditions: value ? '' : state.medicalConditions,
    );
    // Persist to backend
    saveProfile(
      noMedicalConditions: value,
      medicalConditions: value ? '' : state.medicalConditions,
    ).catchError((Object e) { debugPrint('[ProfileSync] background save failed: $e'); return null; });
  }

  // Reactive validation method for when rules change
  void validateWithPolicy(RegistrationRequirementsEntity? policy) {
    if (policy == null) {
      // If no policy, we consider it valid or fall back to defaults
      state = state.copyWith(hasPersonalData: true, hasMedicalData: true);
      return;
    }

    bool isPersonalValid = true;
    bool isMedicalValid = true;

    if (policy.phoneNumber && state.phoneNumber.isEmpty) {
      isPersonalValid = false;
    }
    if (policy.personalNumber && state.personalNumber.isEmpty) {
      isPersonalValid = false;
    }
    if (policy.address && state.address.isEmpty) {
      isPersonalValid = false;
    }
    if (policy.idPhoto && state.idImagePath == null) {
      isPersonalValid = false;
    }

    if (policy.healthInfo &&
        state.medicalConditions.isEmpty &&
        !state.noMedicalConditions) {
      isMedicalValid = false;
    }

    state = state.copyWith(
      hasPersonalData: isPersonalValid,
      hasMedicalData: isMedicalValid,
    );
  }

  Future<String?> _uploadFile(File file, String category) async {
    try {
      final dio = _ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
      });

      final response = await dio.post(
        '/upload/$category',
        data: formData,
        options: Options(validateStatus: (_) => true),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];
        return data['url'] as String?;
      } else {
        final errorObj = response.data['error'];
        String errorMessage = 'Upload failed';
        if (errorObj is Map) {
          errorMessage = errorObj['message']?.toString() ?? errorMessage;
          final details = errorObj['details'];
          if (details is List && details.isNotEmpty) {
            errorMessage = details[0]['message']?.toString() ?? errorMessage;
          }
        }
        throw 'Failed to upload $category: $errorMessage';
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.connectionTimeout) {
        throw 'Upload timed out. Please check your connection.';
      }
      rethrow;
    }
  }
}
