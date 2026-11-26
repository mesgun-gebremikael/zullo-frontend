import '../models/swipe_profile.dart';
import 'message_notification_handler.dart';
import 'match_notification_handler.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_open_request.dart';
import 'account_session.dart';
import 'chat_coordinator.dart';

/// Starts push registration independently of cold-start notification routing.
///
/// Call after the first frame. Registration or APNs permission must never delay
/// the initial-message lookup. A cold-start chat is only queued: normal startup
/// still decides whether to show login, profile setup or the authenticated app.
class NotificationStartup {
  NotificationStartup({
    required this.register,
    required this.initialMessage,
    Future<bool> Function(String peer, String recipient)? canOpen,
    Future<SwipeProfile> Function(String peer)? profile,
    void Function(ChatOpenRequest request)? enqueue,
    Future<ChatOpenRequest?> Function(RemoteMessage message)? resolveMatch,
    this.initialMessageTimeout = const Duration(seconds: 5),
  })  : _resolveMessage =
            MessageNotificationHandler(canOpen: canOpen, profile: profile)
                .resolve,
        _enqueue = enqueue ?? ChatCoordinator.instance.requestOpenChat,
        _resolveMatch =
            resolveMatch ?? MatchNotificationHandler(canOpen: canOpen).resolve;

  final Future<void> Function() register;
  final Future<RemoteMessage?> Function() initialMessage;
  final Future<ChatOpenRequest?> Function(RemoteMessage message)
      _resolveMessage;
  final void Function(ChatOpenRequest request) _enqueue;
  final Duration initialMessageTimeout;
  final Future<ChatOpenRequest?> Function(RemoteMessage message) _resolveMatch;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final generation = AccountSession.generation;
    unawaited(_register());
    try {
      final message = await initialMessage().timeout(initialMessageTimeout);
      if (message == null || !AccountSession.isCurrent(generation)) return;
      final data = message.data;
      if (data['type'] == 'match') {
        final request = await _resolveMatch(message);
        if (request != null && AccountSession.isCurrent(generation)) {
          _enqueue(request);
        }
        return;
      }
      final request = await _resolveMessage(message);
      if (request != null && AccountSession.isCurrent(generation)) {
        _enqueue(request);
      }
    } catch (_) {
      // Startup remains usable while storage, Firebase or chat access is offline.
      // Do not log notification payloads or exception details.
      debugPrint('Initial notification could not be opened.');
    }
  }

  Future<void> _register() async {
    try {
      await register();
    } catch (_) {
      debugPrint('Push registration is unavailable.');
    }
  }
}
