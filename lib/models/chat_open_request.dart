import '../models/chat_open_request.dart';

class ChatOpenRequest {
  final String userId;
  final String displayName;
  final String photoUrl;
  final bool openChatsListOnExit;
  final bool fromNotification;
  final bool forceRefreshThread;

  const ChatOpenRequest({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    this.openChatsListOnExit = false,
    this.fromNotification = false,
    this.forceRefreshThread = false,
  });

  bool get isValid => userId.trim().isNotEmpty;
}