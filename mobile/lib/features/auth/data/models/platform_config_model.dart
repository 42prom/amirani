class PlatformConfigModel {
  final bool googleEnabled;
  final String? googleClientId;
  final bool appleEnabled;
  final String? appleClientId;
  final bool fcmEnabled;
  final String? fcmProjectId;
  /// Whether AI plan generation is enabled globally (set by super admin).
  /// Mobile should check this before triggering generation and surface a
  /// graceful message instead of silently polling until timeout.
  final bool aiEnabled;

  PlatformConfigModel({
    required this.googleEnabled,
    this.googleClientId,
    required this.appleEnabled,
    this.appleClientId,
    required this.fcmEnabled,
    this.fcmProjectId,
    this.aiEnabled = false,
  });

  factory PlatformConfigModel.fromJson(Map<String, dynamic> json) {
    return PlatformConfigModel(
      googleEnabled: json['googleEnabled'] ?? false,
      googleClientId: json['googleClientId'],
      appleEnabled: json['appleEnabled'] ?? false,
      appleClientId: json['appleClientId'],
      fcmEnabled: json['fcmEnabled'] ?? false,
      fcmProjectId: json['fcmProjectId'],
      aiEnabled: json['aiEnabled'] ?? false,
    );
  }
}
