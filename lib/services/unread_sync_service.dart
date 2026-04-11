import 'dart:async';

class UnreadSyncService {
  UnreadSyncService._();
  static final UnreadSyncService instance = UnreadSyncService._();

  final StreamController<String> _openedChatController =
      StreamController<String>.broadcast();

  final Map<String, DateTime> _openedAtByUserId = {};

  Stream<String> get openedChatStream => _openedChatController.stream;

  void markChatOpened(String userId) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return;

    _openedAtByUserId[trimmed] = DateTime.now().toUtc();
    _openedChatController.add(trimmed);
  }

  DateTime? getOpenedAt(String userId) {
    return _openedAtByUserId[userId.trim()];
  }
}