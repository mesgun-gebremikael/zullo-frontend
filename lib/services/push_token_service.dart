import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// APNs registration can complete after notification permission was granted.
/// A missing/slow push token must not prevent login or app startup.
class PushTokenService {
  final bool waitForApns;
  final Future<String?> Function() getApnsToken;
  final Future<String?> Function() getFcmToken;
  final Future<void> Function(Duration) delay;
  final Duration timeout;
  final Duration retryDelay;
  final int attempts;

  PushTokenService({
    required this.waitForApns,
    required this.getApnsToken,
    required this.getFcmToken,
    Future<void> Function(Duration)? delay,
    this.timeout = const Duration(seconds: 3),
    this.retryDelay = const Duration(milliseconds: 500),
    this.attempts = 3,
  }) : delay = delay ?? Future<void>.delayed;

  static Future<String?> currentToken() => PushTokenService(
        waitForApns: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
        getApnsToken: FirebaseMessaging.instance.getAPNSToken,
        getFcmToken: () => FirebaseMessaging.instance.getToken(),
      ).load();

  Future<String?> load() async {
    try {
      if (waitForApns) {
        var ready = false;
        for (var attempt = 0; attempt < attempts; attempt++) {
          final token = await getApnsToken().timeout(timeout);
          if (token != null && token.isNotEmpty) {
            ready = true;
            break;
          }
          if (attempt + 1 < attempts) {
            await delay(retryDelay);
          }
        }
        if (!ready) return null;
      }
      final token = await getFcmToken().timeout(timeout);
      return token == null || token.trim().isEmpty ? null : token;
    } catch (_) {
      // onTokenRefresh or the next login can register a token later.
      return null;
    }
  }
}
