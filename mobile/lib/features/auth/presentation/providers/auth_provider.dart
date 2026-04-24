import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/failures.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../../core/config/service_availability.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/models/platform_config_model.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/providers/storage_providers.dart';
import '../../../profile/presentation/providers/profile_sync_provider.dart';

// Represents the possible authentication states
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

/// Emitted after login when the backend requires the user to set a new password
/// before accessing the app (e.g. newly created Branch Admin accounts).
class AuthMustChangePassword extends AuthState {
  final UserEntity user;
  AuthMustChangePassword(this.user);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase _loginUseCase;
  final AuthRepository _authRepository;
  GoogleSignIn? _googleSignIn;

  AuthNotifier(this._loginUseCase, this._authRepository) : super(AuthInitial()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = AuthLoading();
    
    // 1. Fetch platform config first
    final configResult = await _authRepository.getAuthConfig();
    configResult.fold(
      (failure) {}, // Ignore failure, fall back to defaults
      (PlatformConfigModel config) {
        ServiceAvailability.googleAuth = config.googleEnabled;
        ServiceAvailability.appleAuth = config.appleEnabled;
        ServiceAvailability.firebase = config.fcmEnabled;
        
        if (config.googleClientId != null && config.googleClientId!.isNotEmpty) {
          // Flagship Singleton Pattern: Only initialize if null OR if the ID changed
          _googleSignIn ??= GoogleSignIn(
            clientId: kIsWeb ? config.googleClientId : null,
            serverClientId: kIsWeb ? null : config.googleClientId,
          );
        } else {
          _googleSignIn = null;
        }
      },
    );

    // 2. Check login status
    final result = await _authRepository.checkAuthStatus();
    result.fold(
      (failure) => state = AuthUnauthenticated(),
      (UserEntity? user) {
        if (user != null) {
          state = AuthAuthenticated(user);
        } else {
          state = AuthUnauthenticated();
        }
      },
    );
  }

  Future<void> login(String email, String password) async {
    state = AuthLoading();
    final result =
        await _loginUseCase(LoginParams(email: email, password: password));

    await result.fold(
      (failure) async => state = AuthError(failure.message),
      (user) async {
        final mustChange = await _authRepository.checkMustChangePassword();
        state = mustChange ? AuthMustChangePassword(user) : AuthAuthenticated(user);
      },
    );
  }

  Future<Either<Failure, void>> changePassword(
      String currentPassword, String newPassword) async {
    final result =
        await _authRepository.changePassword(currentPassword, newPassword);
    result.fold(
      (_) {},
      (_) {
        // On success, transition to authenticated if we were in MustChangePassword
        if (state is AuthMustChangePassword) {
          state = AuthAuthenticated((state as AuthMustChangePassword).user);
        }
      },
    );
    return result;
  }

  Future<void> loginWithGoogle(String countryCode) async {
    if (!ServiceAvailability.googleAuth) {
      state = AuthError('Google sign-in is not configured on this server yet.');
      return;
    }
    state = AuthLoading();
    try {
      if (_googleSignIn == null) {
        throw 'Google Sign-In is not configured on the server. Please check Admin Dashboard.';
      }

      GoogleSignInAccount? googleUser;

      try {
        if (kIsWeb) {
          googleUser = await _googleSignIn!.signInSilently();
        }
      } catch (e) {
        // Silent sign-in might fail, which is expected if the user hasn't signed in recently.
      }

      googleUser ??= await _googleSignIn!.signIn();

      if (googleUser == null) {
        state = AuthUnauthenticated();
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        state = AuthError('Google sign-in failed: no ID token. Please use a regular account.');
        return;
      }

      final result = await _authRepository.loginWithOAuth('google', idToken, countryCode: countryCode);

      result.fold(
        (failure) => state = AuthError(failure.message),
        (user) => state = AuthAuthenticated(user),
      );
    } catch (e) {
      String errorMessage = 'Google sign-in failed: $e';
      if (e.toString().contains('popup_closed') && kIsWeb) {
        errorMessage = 'Google sign-in failed: The popup was closed or blocked. \n\n'
            'IMPORTANT: Your current local port might not be whitelisted. \n'
            'Please run with: flutter run -d chrome --web-port=5000';
      }
      state = AuthError(errorMessage);
    }
  }

  Future<void> loginWithApple(String countryCode) async {
    state = AuthLoading();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        state = AuthError('Apple sign-in failed: no identity token');
        return;
      }
      final result = await _authRepository.loginWithOAuth('apple', idToken, countryCode: countryCode);
      result.fold(
        (failure) => state = AuthError(failure.message),
        (user) => state = AuthAuthenticated(user),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = AuthUnauthenticated();
      } else {
        state = AuthError('Apple sign-in failed');
      }
    } catch (e) {
      state = AuthError('Apple sign-in failed');
    }
  }

  Future<void> logout() async {
    state = AuthLoading();
    await _authRepository.logout();
    state = AuthUnauthenticated();
  }

  /// Refetches the current user's profile from the server to sync any changes.
  Future<void> refreshProfile() async {
    final result = await _authRepository.checkAuthStatus();
    result.fold(
      (failure) => null, // Keep existing state on error
      (UserEntity? user) {
        if (user != null) {
          state = AuthAuthenticated(user);
        }
      },
    );
  }
}

// ─── Data Layer Providers ───────────────────────────────────────────────────

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    secureStorage: ref.watch(secureStorageProvider),
    localDataSource: ref.watch(profileLocalDataSourceProvider),
  );
});

// ─── Domain Layer Providers ──────────────────────────────────────────────────

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

// ─── Presentation Layer Providers ─────────────────────────────────────────────

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(loginUseCaseProvider),
    ref.watch(authRepositoryProvider),
  );
});

/// Derived provider — exposes the authenticated user directly.
/// Returns null if unauthenticated. Use this everywhere instead of
/// watching the full AuthState union to avoid rebuilding on loading states.
///
/// Usage:
///   final user = ref.watch(currentUserProvider);
///   if (user == null) → redirect to login
final currentUserProvider = Provider<UserEntity?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  if (authState is AuthAuthenticated) return authState.user;
  return null;
});

