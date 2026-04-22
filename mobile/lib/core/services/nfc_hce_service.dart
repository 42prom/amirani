import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Result of an HCE enrollment attempt.
enum HceEnrollResult { success, alreadyEnrolled, notSupported, error }

/// Status of the phone NFC key.
class PhoneKeyStatus {
  final bool isSupported;   // device has NFC + HCE capability
  final bool isNfcOn;       // NFC is turned on in Android settings
  final bool isEnrolled;    // credential registered with backend
  final bool isEnabled;     // HCE service is active
  final String? credential; // 16-char hex credential

  const PhoneKeyStatus({
    required this.isSupported,
    required this.isNfcOn,
    required this.isEnrolled,
    required this.isEnabled,
    this.credential,
  });

  static const notSupported = PhoneKeyStatus(
    isSupported: false,
    isNfcOn: false,
    isEnrolled: false,
    isEnabled: false,
  );
}

/// Service that manages the phone-as-NFC-key feature via Android HCE.
///
/// On Android:
///   - Uses MethodChannel "com.amirani/hce" backed by AmiraniHceService.kt
///   - The HCE service runs in background (no app needed) once enrolled
///
/// On iOS:
///   - HCE is not supported (returns [PhoneKeyStatus.notSupported])
///
/// Typical flow:
///   1. Call [getStatus()] → shows current state
///   2. If not enrolled, call [enroll(gymId, userId, enrollCallback)]
///      → generates credential, calls enrollCallback (backend API), enables HCE
///   3. Member taps phone to MFRC522 reader at gym entrance
///   4. Pi does APDU exchange → gets credential → validates with backend
///   5. Relay triggers → AVAX S150 opens
class NfcHceService {
  static const _channel = MethodChannel('com.amirani/hce');
  static const _storage = FlutterSecureStorage();
  static const _keyEnrolledGymId = 'hce_enrolled_gym_id';

  /// Returns current phone key status.
  static Future<PhoneKeyStatus> getStatus() async {
    if (kIsWeb || !Platform.isAndroid) return PhoneKeyStatus.notSupported;

    try {
      final supported = await _channel.invokeMethod<bool>('isHceSupported') ?? false;
      if (!supported) return PhoneKeyStatus.notSupported;

      final nfcOn = await _channel.invokeMethod<bool>('isNfcEnabled') ?? false;
      final cred = await _channel.invokeMethod<String?>('getCred');
      final enabled = await _channel.invokeMethod<bool>('isHceEnabled') ?? false;
      final enrolledGymId = await _storage.read(key: _keyEnrolledGymId);

      return PhoneKeyStatus(
        isSupported: true,
        isNfcOn: nfcOn,
        isEnrolled: cred != null && enrolledGymId != null,
        isEnabled: enabled,
        credential: cred,
      );
    } on PlatformException {
      return PhoneKeyStatus.notSupported;
    }
  }

  /// Enroll this phone as an NFC key for [gymId].
  ///
  /// [enrollCallback] should call the backend API to register the card credential.
  /// It receives the 16-char hex credential and should return true on success.
  static Future<HceEnrollResult> enroll({
    required String gymId,
    required Future<bool> Function(String credentialHex) enrollCallback,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return HceEnrollResult.notSupported;

    try {
      final supported = await _channel.invokeMethod<bool>('isHceSupported') ?? false;
      if (!supported) return HceEnrollResult.notSupported;

      // Generate or retrieve credential
      final cred = await _channel.invokeMethod<String>('getOrCreateCred');
      if (cred == null || cred.length != 16) return HceEnrollResult.error;

      // Check if already enrolled for this gym
      final existing = await _storage.read(key: _keyEnrolledGymId);
      if (existing == gymId) return HceEnrollResult.alreadyEnrolled;

      // Call backend to register card
      final ok = await enrollCallback(cred);
      if (!ok) return HceEnrollResult.error;

      // Mark as enrolled and enable HCE
      await _storage.write(key: _keyEnrolledGymId, value: gymId);
      await _channel.invokeMethod('enableHce');

      return HceEnrollResult.success;
    } on PlatformException {
      return HceEnrollResult.error;
    }
  }

  /// Remove phone key enrollment (also calls [revokeCallback] for backend cleanup).
  static Future<bool> unenroll({
    required Future<bool> Function(String credentialHex) revokeCallback,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final cred = await _channel.invokeMethod<String?>('getCred');
      if (cred != null) {
        await revokeCallback(cred);
      }
      await _channel.invokeMethod('clearCred');
      await _storage.delete(key: _keyEnrolledGymId);
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Enable HCE after it was disabled (without re-enrolling).
  static Future<void> enable() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _channel.invokeMethod('enableHce');
  }

  /// Temporarily disable HCE (credential stays stored for re-enabling).
  static Future<void> disable() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _channel.invokeMethod('disableHce');
  }
}
