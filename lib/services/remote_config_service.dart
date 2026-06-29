import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  /// Call once during app startup (after Firebase.initializeApp).
  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        // Fetch fresh values every hour in production; every 30 seconds in debug.
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode
            ? const Duration(seconds: 30)
            : const Duration(hours: 1),
      ));

      // Safe default — empty key means AI chat won't work until key is set.
      await _remoteConfig.setDefaults(const {
        'groq_api_key': '',
      });

      await _remoteConfig.fetchAndActivate();
      debugPrint('✅ Remote Config fetched and activated.');
    } catch (e) {
      debugPrint('⚠️  Remote Config fetch failed: $e. Using cached/default values.');
    }
  }

  /// Returns the Groq API key stored in Firebase Remote Config.
  String get groqApiKey => _remoteConfig.getString('groq_api_key');
}

// Global singleton
final remoteConfigService = RemoteConfigService();
