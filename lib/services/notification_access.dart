import 'account_session.dart';
import 'auth_service.dart';
import 'auth_storage.dart';

class NotificationAccess {
  static Future<bool> isCurrentRecipient(String recipient) async {
    final generation = AccountSession.generation;
    try {
      final user = await AuthStorage().getUserId();
      return AccountSession.isCurrent(generation) &&
          AccountSession.notificationBelongsTo(recipient, user);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canOpen(String peer, String recipient,
      {AuthService? auth}) async {
    final generation = AccountSession.generation;
    try {
      final currentUserId = await AuthStorage().getUserId();
      if (!AccountSession.isCurrent(generation) ||
          !AccountSession.notificationBelongsTo(recipient, currentUserId)) {
        return false;
      }
      final allowed = await (auth ?? AuthService()).canOpenChat(peer);
      return allowed && AccountSession.isCurrent(generation);
    } catch (_) {
      return false;
    }
  }
}
