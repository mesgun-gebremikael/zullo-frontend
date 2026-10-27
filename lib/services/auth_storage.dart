import 'package:shared_preferences/shared_preferences.dart';
import 'account_session.dart';

class AuthStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';
  static Future<void> _writes = Future.value();

  // Serialize credential updates so a slow logout cannot erase a newer login.
  Future<void> _write(int generation, Future<void> Function() action) {
    final operation = _writes.then((_) async {
      AccountSession.check(generation);
      await action();
      AccountSession.check(generation);
    });
    _writes = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> saveAuth({required String token, required String userId}) {
    if (token.isEmpty || userId.isEmpty) {
      throw ArgumentError('Both token and userId are required');
    }
    final generation = AccountSession.reset();
    return _write(generation, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userIdKey, userId);
    });
  }

  Future<void> saveToken(String token) async {
    final userId = await getUserId();
    if (userId == null) throw StateError('No account for token');
    await saveAuth(token: token, userId: userId);
  }

  Future<void> saveUserId(String userId) async {
    final token = await getToken();
    if (token == null) throw StateError('No token for account');
    await saveAuth(token: token, userId: userId);
  }

  Future<String?> _read(String key) async {
    final generation = AccountSession.generation;
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    AccountSession.check(generation);
    return prefs.getString(key);
  }

  Future<String?> getToken() => _read(_tokenKey);
  Future<String?> getUserId() => _read(_userIdKey);

  Future<void> clearAuth() {
    final generation = AccountSession.reset();
    return _write(generation, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
    });
  }

  Future<void> clearToken() => clearAuth();
}
