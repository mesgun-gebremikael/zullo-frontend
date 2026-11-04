import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_open_request.dart';
import 'account_session.dart';
import 'chat_coordinator.dart';
import 'notification_access.dart';

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
    void Function(ChatOpenRequest request)? enqueue,
    this.initialMessageTimeout = const Duration(seconds: 5),
  })  : _canOpen = canOpen ?? NotificationAccess.canOpen,
        _enqueue = enqueue ?? ChatCoordinator.instance.requestOpenChat;

  final Future<void> Function() register;
  final Future<RemoteMessage?> Function() initialMessage;
  final Future<bool> Function(String peer, String recipient) _canOpen;
  final void Function(ChatOpenRequest request) _enqueue;
  final Duration initialMessageTimeout;
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
      if (data['type'] != 'message') return;
      final peer = data['senderUserId'];
      final recipient = data['recipientUserId'];
      if (peer is! String ||
          peer.trim().isEmpty ||
          recipient is! String ||
          recipient.trim().isEmpty) {
        return;
      }
      final allowed = await _canOpen(peer, recipient);
      if (!allowed || !AccountSession.isCurrent(generation)) return;
      _enqueue(ChatOpenRequest(
        userId: peer,
        displayName: data['senderName'] is String ? data['senderName'] : 'Chat',
        photoUrl:
            data['senderPhotoUrl'] is String ? data['senderPhotoUrl'] : '',
        openChatsListOnExit: true,
        fromNotification: true,
        forceRefreshThread: true,
        previewMessageText:
            (data['messageText'] ?? message.notification?.body ?? '')
                .toString(),
        previewMessageAtUtc: DateTime.now().toUtc().toIso8601String(),
      ));
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
