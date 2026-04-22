/// Runtime capability flags — set once during app startup.
///
/// Each flag is true only after the corresponding service initialises
/// successfully.  The rest of the app reads these flags to show or hide
/// features that depend on optional external services (Firebase, OAuth, etc.).
class ServiceAvailability {
  ServiceAvailability._();

  /// Firebase was initialised successfully (google-services.json present or dynamic project ID).
  /// When false: push notifications are limited.
  static bool firebase = false;

  /// Google Sign-In is ready to use.
  /// Can be enabled via Firebase OR via manual Web Client ID.
  static bool googleAuth = false;

  /// Apple Sign-In status from backend.
  static bool appleAuth = false;
}
