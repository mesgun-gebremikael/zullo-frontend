import 'dart:async';

import 'chat_cache_service.dart';
import 'chat_coordinator.dart';
import 'chat_repository.dart';
import 'chat_thread_cache_service.dart';
import 'current_chat.dart';
import 'matches_cache_service.dart';
import 'unread_sync_service.dart';

class SessionChangedException implements Exception {
  @override
  String toString() => 'Sessionen har ändrats. Försök igen efter inloggning.';
}

/// A new generation invalidates work even when the same account logs in again.
class AccountSession {
  static int _generation = 0;
  static final _changes = StreamController<int>.broadcast(sync: true);
  static int get generation => _generation;
  static Stream<int> get changes => _changes.stream;
  static bool isCurrent(int generation) => generation == _generation;

  static void check(int generation) {
    if (!isCurrent(generation)) throw SessionChangedException();
  }

  static bool notificationBelongsTo(String? recipient, String? currentUserId) =>
      recipient != null &&
      recipient.isNotEmpty &&
      currentUserId != null &&
      recipient == currentUserId;

  static int reset() {
    _generation++;
    ChatCacheService.clearAll();
    ChatThreadCacheService.clearAll();
    MatchesCacheService.clear();
    ChatRepository.instance.clear();
    UnreadSyncService.instance.clear();
    ChatCoordinator.instance.clearPendingRequest();
    CurrentChat.openUserId = null;
    _changes.add(_generation);
    return _generation;
  }
}
