import 'current_chat.dart';

/// Bound retained in-memory history. The active screen keeps its own loaded pages.
class ConversationCachePolicy {
  static const maxThreads = 20;
  static const maxMessages = 200;
  static void put<T>(
      Map<String, List<T>> cache, String peer, List<T> messages) {
    cache.remove(peer);
    cache[peer] = List<T>.from(messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages);
    while (cache.length > maxThreads) {
      final oldest =
          cache.keys.firstWhere((key) => key != CurrentChat.openUserId);
      cache.remove(oldest);
    }
  }
}
