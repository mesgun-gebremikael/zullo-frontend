
import 'package:app_badge_plus/app_badge_plus.dart';
import 'auth_service.dart';

class BadgeService {
  static Future<void> refreshUnreadBadge() async {
    try {
      final matches = await AuthService().getMatches();

      int unreadTotal = 0;

      for (final m in matches) {
        final value = m['unreadMessageCount'];

        if (value is int) {
          unreadTotal += value;
        } else if (value is String) {
          unreadTotal += int.tryParse(value) ?? 0;
        }
      }

      await AppBadgePlus.updateBadge(unreadTotal);
    } catch (e) {
      print('Badge refresh error: $e');
    }
  }
}
