import 'package:flutter/foundation.dart';

/// Backend location. Override at build/run time:
///   flutter run --dart-define=API_URL=http://192.168.1.20:5000
/// Defaults: Android emulator reaches the host PC at 10.0.2.2; web/desktop use localhost.
class ApiConfig {
  static const String _override = String.fromEnvironment('API_URL');

  /// Set --dart-define=MAPS_ENABLED=true once a Google Maps API key is configured
  /// (see mobile_app/README.md). Without it the app shows the stop-timeline view.
  static const bool mapsEnabled = bool.fromEnvironment('MAPS_ENABLED');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override.replaceAll(RegExp(r'/$'), '');
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }

  static String get apiUrl => '$baseUrl/api/v1';

  static String get wsUrl => baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
}
