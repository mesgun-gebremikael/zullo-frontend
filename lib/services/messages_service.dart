import 'account_session.dart';
import 'session_http_client.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_storage.dart';

class ChatRequestException implements Exception {
  final int statusCode;
  final String message;
  ChatRequestException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class MessagePage {
  final List<dynamic> messages;
  final bool hasMore;
  final String? nextCursor;
  final String? latestCursor;
  final int? outgoingReadThrough;
  final DateTime? outgoingReadAtUtc;
  MessagePage(this.messages, this.hasMore, this.nextCursor, this.latestCursor,
      {this.outgoingReadThrough, this.outgoingReadAtUtc});
}

class MessagesService {
  final String baseApiUrl;
  final AuthStorage _storage;

  static final http.Client _sharedTransport = http.Client();
  final http.Client _client;
  MessagesService(this.baseApiUrl, this._storage, {http.Client? client})
      : _client = _sessionClient(client ?? _sharedTransport);

  static http.Client _sessionClient(http.Client client) {
    final generation = AccountSession.generation;
    return SessionHttpClient(client, generation: () => generation);
  }

  Future<MessagePage> getThreadPage(String peer,
      {String? before, String? after, int take = 50}) async {
    final token = await _storage.getToken();
    final response = await _client.get(
      Uri.parse('$baseApiUrl/messages/thread-page').replace(queryParameters: {
        'otherUserId': peer,
        'take': '$take',
        if (before != null) 'before': before,
        if (after != null) 'after': after,
      }),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw ChatRequestException(
          response.statusCode,
          response.statusCode == 401 || response.statusCode == 403
              ? 'Konversationen är inte längre tillgänglig.'
              : 'Kunde inte hämta meddelanden. Försök igen.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return MessagePage(
        data['messages'] as List<dynamic>,
        data['hasMore'] == true,
        data['nextCursor'] as String?,
        data['latestCursor'] as String?,
        outgoingReadThrough: (data['outgoingReadThrough'] as num?)?.toInt(),
        outgoingReadAtUtc:
            DateTime.tryParse((data['outgoingReadAtUtc'] ?? '').toString())
                ?.toUtc());
  }

  // ✅ använd i ChatPage för att veta vem "jag" är
  Future<String?> getMeUserId() => _storage.getUserId();

  Future<List<dynamic>> getThread(String otherUserId) async {
    final token = await _storage.getToken();

    final uri = Uri.parse('$baseApiUrl/messages/thread')
        .replace(queryParameters: {'otherUserId': otherUserId});

    final res = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      return (decoded as List).cast<dynamic>();
    }

    throw Exception('Thread failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> sendMessage({
    required String toUserId,
    required String text,
    required String clientMessageId,
  }) async {
    final token = await _storage.getToken();

    final res = await _client
        .post(
          Uri.parse('$baseApiUrl/messages/send'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'toUserId': toUserId,
            'text': text,
            'clientMessageId': clientMessageId,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      return (decoded as Map).cast<String, dynamic>();
    }

    if (res.statusCode == 429) {
      final seconds = int.tryParse(res.headers['retry-after'] ?? '') ?? 2;
      throw ChatRequestException(429,
          'Du skickar för snabbt. Vänta ${seconds.clamp(1, 60)} sekunder och försök igen.');
    }
    throw ChatRequestException(
        res.statusCode,
        res.statusCode == 401 || res.statusCode == 403
            ? 'Konversationen är inte längre tillgänglig.'
            : 'Meddelandet kunde inte bekräftas. Försök igen.');
  }

  Future<void> markRead(String otherUserId) async {
    final token = await _storage.getToken();

    final uri = Uri.parse('$baseApiUrl/messages/mark-read')
        .replace(queryParameters: {'otherUserId': otherUserId});

    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('markRead failed: ${res.statusCode} ${res.body}');
    }
  }
}
