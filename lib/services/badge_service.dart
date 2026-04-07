
import 'package:app_badge_plus/app_badge_plus.dart';
import 'auth_service.dart';

class BadgeService {
  static Future<void> refreshUnreadBadge() async {
    try {
      final matches = await AuthService().getMatches();

      final unreadChats = matches
          .where((m) => m['hasUnread'] == true)
          .length;

      await AppBadgePlus.updateBadge(unreadChats);
    } catch (e) {
      print('Badge refresh error: $e');
    }
  }
}
