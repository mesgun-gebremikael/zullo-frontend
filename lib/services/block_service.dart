import 'api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';
import 'account_session.dart';
import 'relation_changes.dart';

class BlockService {
  final http.Client _client;
  final AuthStorage _storage;
  BlockService({http.Client? client, AuthStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? AuthStorage();

  Future<http.Response> _request(String method, String path,
      {Object? body}) async {
    final generation = AccountSession.generation;
    final token = await _storage.getToken();
    AccountSession.check(generation);
    final request =
        http.Request(method, Uri.parse('${ApiConfig.baseUrl}$path'));
    request.headers.addAll(
        {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
    if (body != null) request.body = jsonEncode(body);
    final res = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 15));
    AccountSession.check(generation);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Kunde inte uppdatera blockering.');
    }
    return res;
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final res = await _request('GET', '/blocks');
    return (jsonDecode(res.body) as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> blockUser(String userId) async {
    await _request('POST', '/blocks', body: {'blockedUserId': userId});
    RelationChanges.notify(userId);
  }

  Future<void> unblockUser(String userId) async {
    await _request('DELETE', '/blocks/$userId');
    RelationChanges.notify(userId);
  }
}
