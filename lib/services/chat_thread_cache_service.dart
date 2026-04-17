class ChatThreadCacheService {
  ChatThreadCacheService._();

  static final Map<String, List<dynamic>> _threads = {};

  static List<dynamic>? getThread(String userId) {
    final data = _threads[userId];
    if (data == null) return null;
    return List<dynamic>.from(data);
  }

  static void setThread(String userId, List<dynamic> thread) {
    _threads[userId] = List<dynamic>.from(thread);
  }

  static bool hasThread(String userId) {
    final data = _threads[userId];
    return data != null && data.isNotEmpty;
  }

  static void clearThread(String userId) {
    _threads.remove(userId);
  }

  static void clearAll() {
    _threads.clear();
  }
}