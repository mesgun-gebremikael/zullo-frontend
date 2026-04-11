import 'dart:async';
import '../models/chat_open_request.dart';

class ChatCoordinator {
  ChatCoordinator._();
  static final ChatCoordinator instance = ChatCoordinator._();

  final StreamController<ChatOpenRequest> _openChatController =
      StreamController<ChatOpenRequest>.broadcast();

  ChatOpenRequest? _pendingRequest;

  Stream<ChatOpenRequest> get openChatStream => _openChatController.stream;

  ChatOpenRequest? get pendingRequest => _pendingRequest;

  void requestOpenChat(ChatOpenRequest request) {
    if (!request.isValid) return;

    _pendingRequest = request;
    _openChatController.add(request);
  }

  ChatOpenRequest? consumePendingRequest() {
    final request = _pendingRequest;
    _pendingRequest = null;
    return request;
  }

  void clearPendingRequest() {
    _pendingRequest = null;
  }
}