import 'onboarding_draft_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'account_session.dart';
import 'api_config.dart';
import 'auth_storage.dart';
import 'session_http_client.dart';

class AccountException implements Exception {
  final int status;
  final String message;
  const AccountException(this.status, this.message);
}

class AccountService {
  final int _generation = AccountSession.generation;
  final AuthStorage _storage;
  final http.Client _transport;
  static final _shared = http.Client();
  late final _client =
      SessionHttpClient(_transport, generation: () => _generation);
  AccountService({http.Client? client, AuthStorage? storage})
      : _transport = client ?? _shared,
        _storage = storage ?? AuthStorage();
  Future<Map<String, dynamic>> _request(String method, String path,
      [Object? body]) async {
    AccountSession.check(_generation);
    final token = await _storage.getToken();
    AccountSession.check(_generation);
    final request =
        http.Request(method, Uri.parse('${ApiConfig.baseUrl}/me/account$path'));
    request.headers.addAll(
        {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
    if (body != null) request.body = jsonEncode(body);
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 20));
    AccountSession.check(_generation);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Kunde inte bekräfta ändringen. Försök igen.';
      try {
        message = (jsonDecode(response.body) as Map)['message']?.toString() ??
            message;
      } catch (_) {/* generic message */}
      throw AccountException(response.statusCode, message);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<bool> paused() async =>
      (await _request('GET', '/status'))['paused'] == true;
  Future<bool> pause(bool value) async =>
      (await _request('PATCH', '/pause', {'paused': value}))['paused'] == true;
  Future<Map<String, dynamic>> remove(String password) async {
    String? user;
    try {
      user = await _storage.getUserId().timeout(const Duration(seconds: 5));
    } catch (_) {/* optional local cache cleanup */}
    AccountSession.check(_generation);
    final result = await _request(
        'POST', '/removal', {'password': password, 'confirm': true});
    if (user != null) {
      try {
        await DraftCache().clear(user).timeout(const Duration(seconds: 5));
      } catch (_) {/* server erasure remains accepted */}
    }
    return result;
  }
}
