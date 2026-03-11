import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';

class BlockService {
  static const String _baseUrl = "http://localhost:5125";

  final AuthStorage _storage = AuthStorage();

  Future<void> blockUser(String userId) async {
    final token = await _storage.getToken();

    final res = await http.post(
      Uri.parse("$_baseUrl/blocks"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "blockedUserId": userId,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to block user: ${res.statusCode} ${res.body}");
    }
  }
}