import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/chat_open_request.dart';
import '../models/swipe_profile.dart';
import 'account_session.dart';
import 'auth_service.dart';
import 'notification_access.dart';

/// Resolves identity from the authorized profile endpoint, never push payload copy.
/// A match alert cannot bypass login, profile setup, blocks or a newer account.
class MatchNotificationHandler {
  MatchNotificationHandler({
    Future<bool> Function(String peer, String recipient)? canOpen,
    Future<SwipeProfile> Function(String peer)? profile,
  })  : _canOpen = canOpen ?? NotificationAccess.canOpen,
        _profile = profile ?? AuthService().getMatchedProfile;

  final Future<bool> Function(String peer, String recipient) _canOpen;
  final Future<SwipeProfile> Function(String peer) _profile;

  static String? eventId(RemoteMessage message) {
    if (message.data['type'] != 'match') return null;
    final id = message.data['matchId'];
    final event = message.data['eventId'];
    if (id is! String || id.trim().isEmpty || event != 'match-$id') return null;
    return event as String;
  }

  Future<ChatOpenRequest?> resolve(RemoteMessage message) async {
    final generation = AccountSession.generation;
    if (eventId(message) == null) return null;
    final peer = message.data['senderUserId'];
    final recipient = message.data['recipientUserId'];
    if (peer is! String ||
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
      // Revocation, expired authentication and offline operation reveal nothing.
      return null;
    }
  }
}
