class ChatListItem {
  final String userId;
  final String displayName;
  final String photoUrl;
  final int age;
  final String lastMessageText;
  final DateTime? lastMessageAtUtc;
  final bool hasUnread;
  final int unreadMessageCount;

  const ChatListItem({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.age,
    required this.lastMessageText,
    required this.lastMessageAtUtc,
    required this.hasUnread,
    required this.unreadMessageCount,
  });

  ChatListItem copyWith({
    String? userId,
    String? displayName,
    String? photoUrl,
    int? age,
    String? lastMessageText,
    DateTime? lastMessageAtUtc,
    bool? hasUnread,
    int? unreadMessageCount,
  }) {
    return ChatListItem(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      age: age ?? this.age,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageAtUtc: lastMessageAtUtc ?? this.lastMessageAtUtc,
      hasUnread: hasUnread ?? this.hasUnread,
      unreadMessageCount: unreadMessageCount ?? this.unreadMessageCount,
    );
  }

  static DateTime? tryParseUtc(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  factory ChatListItem.fromJson(Map<String, dynamic> json) {
    return ChatListItem(
      userId: (json['userId'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      photoUrl: (json['photoUrl'] ?? '').toString(),
      age: (json['age'] as num?)?.toInt() ?? 0,
      lastMessageText: (json['lastMessageText'] ?? '').toString(),
      lastMessageAtUtc: tryParseUtc(json['lastMessageAtUtc']),
      hasUnread: json['hasUnread'] == true,
      unreadMessageCount: (json['unreadMessageCount'] as num?)?.toInt() ?? 0,
    );
  }
}