import 'dart:async';

class UnreadSyncService {
  UnreadSyncService._();
  static final UnreadSyncService instance = UnreadSyncService._();

  final StreamController<String> _openedChatController =
      StreamController<String>.broadcast();

  Stream<String> get openedChatStream => _openedChatController.stream;

  void markChatOpened(String userId) {
    if (userId.trim().isEmpty) return;
    _openedChatController.add(userId);
  }
}