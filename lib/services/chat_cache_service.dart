class ChatCacheService {
  static final Map<String, List<dynamic>> _cache = {};

  static List<dynamic>? getMessages(String userId) {
    return _cache[userId];
  }

  static void setMessages(String userId, List<dynamic> messages) {
    _cache[userId] = messages;
  }

  static void clear(String userId) {
    _cache.remove(userId);
  }
}
