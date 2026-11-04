import 'app_localizations.dart';

/// Localized presentation of server-provided presence timestamps.
/// Missing timestamps stay absent; future timestamps behave as online.
class PresenceText {
  static String format(DateTime? last,
      {required AppLocalizations strings, DateTime? now}) {
    if (last == null) return '';
    final elapsed = (now ?? DateTime.now()).toUtc().difference(last.toUtc());
    if (elapsed.inSeconds < 90) return strings.onlineNow;
    if (elapsed.inMinutes < 60) {
      return strings.lastActiveMinutes(elapsed.inMinutes);
    }
    if (elapsed.inHours < 24) {
      return strings.lastActiveHours(elapsed.inHours);
    }
    return strings.lastActiveDays(elapsed.inDays);
  }
}
