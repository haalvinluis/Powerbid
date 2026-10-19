import 'package:flutter/foundation.dart';

/// Centralized configuration for PowerBid mobile client.
/// Eliminates hardcoded URLs and provides environment-aware endpoints (dev, staging, production).
class AppConfig {
  /// Build environment: 'development', 'staging', or 'production'.
  /// Can be overridden at build time via:
  /// `flutter build apk --dart-define=ENV=production`
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );

  /// Production Cloud Server URL (HTTPS / WSS).
  /// Configure this with your live cloud hosting domain (e.g. Render, Railway, Fly.io, or VPS).
  static const String productionServerUrl = 'https://api.powerbid.game';

  /// Staging Cloud Server URL for pre-release testing.
  static const String stagingServerUrl = 'https://staging-api.powerbid.game';

  /// Local Development Server URL:
  /// For physical devices over Wi-Fi: use your host machine's LAN IP (e.g. http://10.238.8.1:3000)
  /// For Android Emulator: use http://10.0.2.2:3000
  static const String developmentServerUrl = 'http://10.238.8.1:3000';

  /// Returns the active server URL.
  /// Priority:
  /// 1. Explicit compile-time `--dart-define=SERVER_URL=...`
  /// 2. Environment default (production vs staging vs development)
  static String get defaultServerUrl {
    const customUrl = String.fromEnvironment('SERVER_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }

    switch (environment.toLowerCase()) {
      case 'staging':
        return stagingServerUrl;
      case 'development':
      case 'dev':
      case 'local':
        return developmentServerUrl;
      case 'production':
      case 'prod':
      default:
        return productionServerUrl;
    }
  }

  /// Whether the app is running in production mode.
  static bool get isProduction =>
      environment.toLowerCase() == 'production' || environment.toLowerCase() == 'prod';

  /// Whether the app is running in development mode.
  static bool get isDevelopment =>
      environment.toLowerCase() == 'development' || environment.toLowerCase() == 'dev';
}
