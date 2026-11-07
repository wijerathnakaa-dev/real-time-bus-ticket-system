import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging. The Go server publishes "bus approaching" pushes to
/// the topic `bus_<busId>`; a passenger subscribes after booking on that bus.
/// Everything is a no-op until google-services.json is added (Firebase not initialised).
class PushService {
  static bool _ready = false;

  static bool get isReady => _ready;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission();
      _ready = true;
    } catch (e) {
      debugPrint('[Push] Firebase not configured - push notifications disabled ($e)');
    }
  }

  static Future<void> followBus(String busId) async {
    if (!_ready || kIsWeb) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic('bus_$busId');
    } catch (e) {
      debugPrint('[Push] subscribe failed: $e');
    }
  }

  static Future<void> unfollowBus(String busId) async {
    if (!_ready || kIsWeb) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('bus_$busId');
    } catch (_) {}
  }
}
