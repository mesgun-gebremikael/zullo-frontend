import 'conversation_cache_policy.dart';
class ChatThreadCacheService {
  ChatThreadCacheService._();

  static final Map<String, List<dynamic>> _threads = {};
  static final Map<String, Future<List<dynamic>>> _pending = {};

  static Future<List<dynamic>> loadOnce(String userId, Future<List<dynamic>> Function() load) {
    final active = _pending[userId];
    if (active != null) return active;
    late Future<List<dynamic>> operation;
    operation = Future<List<dynamic>>.microtask(load).whenComplete(() {
      if (identical(_pending[userId], operation)) _pending.remove(userId);
    });
    _pending[userId] = operation;
    return operation;
  }

  static List<dynamic>? getThread(String userId) {
    final data = _threads[userId];
    if (data == null) return null;
    return List<dynamic>.from(data);
  }

  static void setThread(String userId, List<dynamic> thread) {
    ConversationCachePolicy.put(_threads, userId, thread);
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
    _pending.clear();
  }
}