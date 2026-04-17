import 'dart:async';
import '../models/chat_list_item.dart';
import '../models/chat_message_item.dart';

class ChatRepositoryState {
  final List<ChatListItem> chatList;
  final Map<String, List<ChatMessageItem>> threads;

  const ChatRepositoryState({
    required this.chatList,
    required this.threads,
  });

  ChatRepositoryState copyWith({
    List<ChatListItem>? chatList,
    Map<String, List<ChatMessageItem>>? threads,
  }) {
    return ChatRepositoryState(
      chatList: chatList ?? this.chatList,
      threads: threads ?? this.threads,
    );
  }

  static const empty = ChatRepositoryState(
    chatList: [],
    threads: {},
  );
}

class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  final StreamController<ChatRepositoryState> _stateController =
      StreamController<ChatRepositoryState>.broadcast();

  ChatRepositoryState _state = ChatRepositoryState.empty;

  Stream<ChatRepositoryState> get stream => _stateController.stream;
  ChatRepositoryState get state => _state;

  List<ChatListItem> get chatList => _state.chatList;

  List<ChatMessageItem> threadFor(String userId) {
    return List<ChatMessageItem>.from(_state.threads[userId] ?? const []);
  }

  void setChatList(List<ChatListItem> items) {
    _state = _state.copyWith(chatList: List<ChatListItem>.from(items));
    _emit();
  }

  void setThread(String userId, List<ChatMessageItem> messages) {
    final nextThreads = Map<String, List<ChatMessageItem>>.from(_state.threads);
    nextThreads[userId] = List<ChatMessageItem>.from(messages);

    _state = _state.copyWith(threads: nextThreads);
    _emit();
  }

  void clearUnreadForUser(String userId) {
    final nextList = _state.chatList.map((item) {
      if (item.userId != userId) return item;

      return item.copyWith(
        hasUnread: false,
        unreadMessageCount: 0,
      );
    }).toList();

    _state = _state.copyWith(chatList: nextList);
    _emit();
  }

  void updateLastMessage({
    required String userId,
    required String text,
    required DateTime messageTimeUtc,
    required bool incrementUnread,
  }) {
    final nextList = _state.chatList.map((item) {
      if (item.userId != userId) return item;

      final nextUnreadCount = incrementUnread
          ? item.unreadMessageCount + 1
          : item.unreadMessageCount;

      return item.copyWith(
        lastMessageText: text,
        lastMessageAtUtc: messageTimeUtc,
        hasUnread: incrementUnread ? true : item.hasUnread,
        unreadMessageCount: nextUnreadCount,
      );
    }).toList();

    nextList.sort((a, b) {
      final aTime = a.lastMessageAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final bTime = b.lastMessageAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return bTime.compareTo(aTime);
    });

    _state = _state.copyWith(chatList: nextList);
    _emit();
  }

  void _emit() {
    _stateController.add(_state);
  }
}