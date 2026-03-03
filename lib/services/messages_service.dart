import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_storage.dart';

class MessagesService {
  final String baseApiUrl;
  final AuthStorage _storage;

  MessagesService(this.baseApiUrl, this._storage);

  // ✅ använd i ChatPage för att veta vem "jag" är
  Future<String?> getMeUserId() => _storage.getUserId();

  Future<List<dynamic>> getThread(String otherUserId) async {
    final token = await _storage.getToken();

    final uri = Uri.parse('$baseApiUrl/messages/thread')
        .replace(queryParameters: {'otherUserId': otherUserId});

    final res = await http.get(
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
  }) async {
    final token = await _storage.getToken();

    final res = await http.post(
      Uri.parse('$baseApiUrl/messages/send'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'toUserId': toUserId,
        'text': text,
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

    final res = await http.post(
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