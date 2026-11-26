import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/chat_open_request.dart';
import '../models/swipe_profile.dart';
import 'account_session.dart';
import 'auth_service.dart';
import 'notification_access.dart';

/// Message push contains routing IDs only. Display identity is fetched after
/// authorization; payload names, avatars and message previews are never trusted.
class MessageNotificationHandler {
  MessageNotificationHandler({
    Future<bool> Function(String peer, String recipient)? canOpen,
    Future<SwipeProfile> Function(String peer)? profile,
  })  : _canOpen = canOpen ?? NotificationAccess.canOpen,
        _profile = profile ?? AuthService().getMatchedProfile;
  final Future<bool> Function(String peer, String recipient) _canOpen;
  final Future<SwipeProfile> Function(String peer) _profile;

  Future<ChatOpenRequest?> resolve(RemoteMessage message) async {
    final generation = AccountSession.generation;
    final data = message.data;
    final peer = data['senderUserId'], recipient = data['recipientUserId'];
    if (data['type'] != 'message' ||
        peer is! String ||
        peer.trim().isEmpty ||
        recipient is! String ||
        recipient.trim().isEmpty ||
        peer == recipient) {
      return null;
    }
    try {
      if (!await _canOpen(peer, recipient) ||
          !AccountSession.isCurrent(generation)) {
        return null;
      }
      final person = await _profile(peer);
      if (!AccountSession.isCurrent(generation) || person.userId != peer) {
        return null;
      }
      return ChatOpenRequest(
        userId: peer,
        displayName: person.displayName,
        photoUrl: person.photoUrls.isEmpty ? '' : person.photoUrls.first,
        openChatsListOnExit: true,
        fromNotification: true,
        forceRefreshThread: true,
      );
    } catch (_) {
      return null;
    }
  }
}
