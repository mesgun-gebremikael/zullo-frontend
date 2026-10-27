import 'account_session.dart';
import 'session_http_client.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_storage.dart';

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

  final res = await _client.post(
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
  );

  if (res.statusCode == 200) {
    final decoded = jsonDecode(res.body);
    return (decoded as Map).cast<String, dynamic>();
  }

  throw Exception('Send failed: ${res.statusCode} ${res.body}');
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