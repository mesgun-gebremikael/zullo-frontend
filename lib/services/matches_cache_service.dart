class MatchesCacheService {
  MatchesCacheService._();

  static List<dynamic>? _matches;
  static List<dynamic>? _likesReceived;

  static List<dynamic>? getMatches() => _matches;
  static List<dynamic>? getLikesReceived() => _likesReceived;

  static void setData({
    required List<dynamic> matches,
    required List<dynamic> likesReceived,
  }) {
    _matches = List<dynamic>.from(matches);
    _likesReceived = List<dynamic>.from(likesReceived);
  }

  static void clearUnreadForUser(String userId) {
    if (_matches == null) return;

    for (final m in _matches!) {
      final currentUserId = (m["userId"] ?? "").toString();
      if (currentUserId != userId) continue;

      m["hasUnread"] = false;
      m["unreadMessageCount"] = 0;
    }
  }

  static void clear() {
    _matches = null;
    _likesReceived = null;
  }
}