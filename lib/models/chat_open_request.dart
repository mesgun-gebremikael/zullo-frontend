import '../models/chat_open_request.dart';

class ChatOpenRequest {
  final String userId;
  final String displayName;
  final String photoUrl;
  final bool openChatsListOnExit;
  final bool fromNotification;
  final bool forceRefreshThread;

  // Preview-message används för att visa nytt meddelande direkt vid öppning
  final String? previewMessageText;
  final String? previewMessageAtUtc;

  const ChatOpenRequest({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    this.openChatsListOnExit = false,
    this.fromNotification = false,
    this.forceRefreshThread = false,
    this.previewMessageText,
    this.previewMessageAtUtc,
  });

  bool get isValid => userId.trim().isNotEmpty;
}