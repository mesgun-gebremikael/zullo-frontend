class MatchesCacheService {
  MatchesCacheService._();

  static int? _generation;
  static Future<List<dynamic>>? _matchesRequest;
  static Future<List<dynamic>>? _likesRequest;

  static Future<List<dynamic>> loadMatches(int generation, Future<List<dynamic>> Function() load) =>
      _load(generation, load, matches: true);
  static Future<List<dynamic>> loadLikes(int generation, Future<List<dynamic>> Function() load) =>
      _load(generation, load, matches: false);

  static Future<List<dynamic>> _load(int generation, Future<List<dynamic>> Function() load, {required bool matches}) {
    if (_generation != generation) {
      _matchesRequest = null;
      _likesRequest = null;
      _generation = generation;
    }
    final pending = matches ? _matchesRequest : _likesRequest;
    if (pending != null) return pending;
    late Future<List<dynamic>> operation;
    operation = Future<List<dynamic>>.microtask(load).whenComplete(() {
      if (matches && identical(_matchesRequest, operation)) _matchesRequest = null;
      if (!matches && identical(_likesRequest, operation)) _likesRequest = null;
    });
    if (matches) { _matchesRequest = operation; } else { _likesRequest = operation; }
    return operation;
  }

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
    _generation = null;
    _matchesRequest = null;
    _likesRequest = null;
    _matches = null;
    _likesReceived = null;
  }
}