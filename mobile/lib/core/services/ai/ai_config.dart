enum AIStrategy {
  offline, // Use enhanced mock data (fallback)
  api, // Use backend API
  directAI, // Direct DeepSeek API calls
}

class AIConfig {
  final AIStrategy strategy;
  final String? apiBaseUrl;
  final String? apiKey;
  final String model;
  final Duration timeout;

  const AIConfig({
    this.strategy = AIStrategy.api,
    this.apiBaseUrl,
    this.apiKey,
    this.model = 'deepseek-chat',
    this.timeout = const Duration(seconds: 180),
  });

  static const AIConfig defaultConfig = AIConfig();
}
