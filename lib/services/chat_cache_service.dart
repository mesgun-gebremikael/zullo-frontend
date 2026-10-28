import 'conversation_cache_policy.dart';
class ChatCacheService {
  static final Map<String, List<dynamic>> _cache = {};

  static List<dynamic>? getMessages(String userId) {
    final cached = _cache[userId];
    return cached == null ? null : List<dynamic>.from(cached);
  }

  static void setMessages(String userId, List<dynamic> messages) {
    ConversationCachePolicy.put(_cache, userId, messages);
  }

  static void clearAll() => _cache.clear();

  static void clear(String userId) {
    _cache.remove(userId);
  }
}
