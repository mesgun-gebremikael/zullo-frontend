/// Stable question keys and the user's unchanged answer.
class ProfileConversationPrompt {
  final String key;
  final String answer;
  const ProfileConversationPrompt({required this.key, required this.answer});
  ProfileConversationPrompt copyWith({String? key, String? answer}) =>
      ProfileConversationPrompt(
          key: key ?? this.key, answer: answer ?? this.answer);
  Map<String, dynamic> toJson() => {'key': key, 'answer': answer};

  static List<ProfileConversationPrompt> read(Map<String, dynamic> json) {
    if (json['conversationPrompts'] is List) {
      return (json['conversationPrompts'] as List)
          .whereType<Map>()
          .where((p) => p['key'] is String && p['answer'] is String)
          .map((p) => ProfileConversationPrompt(
              key: p['key'] as String, answer: p['answer'] as String))
          .toList();
    }
    final key = json['promptKey'] is String ? json['promptKey'] as String : '';
    final answer =
        json['promptAnswer'] is String ? json['promptAnswer'] as String : '';
    return key.isEmpty
        ? []
        : [ProfileConversationPrompt(key: key, answer: answer)];
  }
}
