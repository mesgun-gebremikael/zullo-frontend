class ChatMessageItem {
  final String text;
  final bool isMe;
  final DateTime timeLocal;
  final DateTime? readAtLocal;
  final bool pending;
  final bool failed;
  final String clientMessageId;

  const ChatMessageItem({
    required this.text,
    required this.isMe,
    required this.timeLocal,
    required this.readAtLocal,
    required this.pending,
    required this.failed,
    required this.clientMessageId,
  });

  ChatMessageItem copyWith({
    String? text,
    bool? isMe,
    DateTime? timeLocal,
    DateTime? readAtLocal,
    bool? pending,
    bool? failed,
    String? clientMessageId,
  }) {
    return ChatMessageItem(
      text: text ?? this.text,
      isMe: isMe ?? this.isMe,
      timeLocal: timeLocal ?? this.timeLocal,
      readAtLocal: readAtLocal ?? this.readAtLocal,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
      clientMessageId: clientMessageId ?? this.clientMessageId,
    );
  }
}