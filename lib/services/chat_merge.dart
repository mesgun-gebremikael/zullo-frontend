import '../models/chat_message_item.dart';

/// Reconcile server snapshots with live, optimistic and failed items without erasing them.
List<ChatMessageItem> mergeChatItems(
    List<ChatMessageItem> existing, List<ChatMessageItem> incoming) {
  final result = List<ChatMessageItem>.from(existing);
  for (final message in incoming) {
    var index = message.serverId == null
        ? -1
        : result.indexWhere((m) => m.serverId == message.serverId);
    if (index < 0 && message.clientMessageId.isNotEmpty) {
      index = result.indexWhere((m) =>
          m.isMe == message.isMe &&
          m.clientMessageId == message.clientMessageId &&
          (m.serverId == null || message.serverId == null));
    }
    if (index < 0) {
      result.add(message);
    } else {
      final old = result[index];
      // A stale optimistic snapshot cannot replace an already confirmed message.
      final confirmed =
          old.serverId != null && message.serverId == null ? old : message;
      result[index] = confirmed.copyWith(
          readAtLocal: message.readAtLocal ?? old.readAtLocal);
    }
  }
  result.sort((a, b) {
    final aLocal = a.serverId == null && (a.pending || a.failed);
    final bLocal = b.serverId == null && (b.pending || b.failed);
    if (aLocal != bLocal) return aLocal ? 1 : -1;
    if (a.sequence != null && b.sequence != null) {
      return a.sequence!.compareTo(b.sequence!);
    }
    return a.timeLocal.compareTo(b.timeLocal);
  });
  return result;
}

/// Monotonic server receipt state also covers acknowledgements arriving before a send response.
class ReadWatermark {
  int? through;
  DateTime? at;
  void accept(int? sequence, DateTime? readAt) {
    if (sequence == null ||
        readAt == null ||
        (through != null && sequence < through!)) {
      return;
    }
    through = sequence;
    at = readAt.toLocal();
  }

  ChatMessageItem apply(ChatMessageItem message) => message.isMe &&
          through != null &&
          message.sequence != null &&
          message.sequence! <= through! &&
          at != null
      ? message.copyWith(readAtLocal: message.readAtLocal ?? at)
      : message;
}
