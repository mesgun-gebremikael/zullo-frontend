import 'dart:async';
import 'chat_repository.dart';
import 'chat_coordinator.dart';
import 'chat_cache_service.dart';
import 'chat_thread_cache_service.dart';
import 'matches_cache_service.dart';
import 'matches_refresh_service.dart';

class RelationChanges {
  static int revision = 0;
  static final _versions = <String, int>{};
  static int versionFor(String userId) => _versions[userId] ?? 0;
  static final _events = StreamController<String>.broadcast(sync: true);
  static Stream<String> get stream => _events.stream;

  static void notify(String otherUserId) {
    if (otherUserId.isEmpty) return;
    revision++;
    _versions[otherUserId] = revision;
    ChatCacheService.clear(otherUserId);
    ChatThreadCacheService.clearThread(otherUserId);
    MatchesCacheService.clear();
    if (ChatCoordinator.instance.pendingRequest?.userId == otherUserId) {
      ChatCoordinator.instance.clearPendingRequest();
    }
    ChatRepository.instance.removeUser(otherUserId);
    _events.add(otherUserId);
    MatchesRefreshService.instance.requestRefresh();
  }
}
