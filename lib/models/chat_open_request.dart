import '../models/chat_open_request.dart';

class ChatOpenRequest {
  final String userId;
  final String displayName;
  final String photoUrl;
  final bool openChatsListOnExit;
  final bool fromNotification;

  const ChatOpenRequest({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    this.openChatsListOnExit = false,
    this.fromNotification = false,
  });

  bool get isValid => userId.trim().isNotEmpty;
}