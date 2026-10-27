import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_session.dart';

class AuthStorage {
  static const String sessionKey = 'auth_session_v1';
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';
  static Future<void> _writes = Future.value();
  static const _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  final FlutterSecureStorage _secure;
  AuthStorage({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? _defaultStorage;

  // Reads/migration and writes share a queue, including across AuthStorage instances.
  Future<T> _serial<T>(int generation, Future<T> Function() action) {
    final operation = _writes.then((_) async {
      AccountSession.check(generation);
      final result = await action();
      AccountSession.check(generation);
      return result;
    });
    _writes = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> _removeLegacy(SharedPreferences prefs) async {
    for (final key in [_tokenKey, _userIdKey]) {
      if (prefs.containsKey(key) && !await prefs.remove(key)) {
        throw StateError('Could not remove legacy credentials');
      }
    }
  }

  String _record(String token, String userId) =>
      jsonEncode({'token': token, 'userId': userId});

  Future<Map<String, dynamic>?> _load() async {
    // A Keychain/Keystore failure must not fall back to plaintext credentials.
    final record = await _secure.read(key: sessionKey);
    final prefs = await SharedPreferences.getInstance();
    if (record != null) {
      Map<String, dynamic>? credentials;
      try {
        final decoded = jsonDecode(record);
        if (decoded is Map<String, dynamic> &&
            decoded['token'] is String &&
            (decoded['token'] as String).isNotEmpty &&
            decoded['userId'] is String &&
            (decoded['userId'] as String).isNotEmpty) {
          credentials = decoded;
        }
      } on FormatException {
        // An incomplete/corrupt identity is treated as signed out.
      }
      await _removeLegacy(prefs);
      if (credentials == null) await _secure.delete(key: sessionKey);
      return credentials;
    }

    final token = prefs.getString(_tokenKey);
    final userId = prefs.getString(_userIdKey);
    if (token != null &&
        token.isNotEmpty &&
        userId != null &&
        userId.isNotEmpty) {
      // Persist the complete identity before deleting either legacy field.
      await _secure.write(key: sessionKey, value: _record(token, userId));
      await _removeLegacy(prefs);
      return {'token': token, 'userId': userId};
    }
    await _removeLegacy(prefs);
    return null;
  }

  Future<void> saveAuth({required String token, required String userId}) {
    if (token.isEmpty || userId.isEmpty) {
      throw ArgumentError('Both token and userId are required');
    }
    final generation = AccountSession.reset();
    return _serial(generation, () async {
      // One encrypted value avoids token/account pairs from different writes.
      await _secure.write(key: sessionKey, value: _record(token, userId));
      await _removeLegacy(await SharedPreferences.getInstance());
    });
  }

  Future<void> saveToken(String token) async {
    final generation = AccountSession.generation;
    final userId = await getUserId();
    AccountSession.check(generation);
    if (userId == null) throw StateError('No account for token');
    await saveAuth(token: token, userId: userId);
  }

  Future<void> saveUserId(String userId) async {
    final generation = AccountSession.generation;
    final token = await getToken();
    AccountSession.check(generation);
    if (token == null) throw StateError('No token for account');
    await saveAuth(token: token, userId: userId);
  }

  Future<String?> _read(String key) =>
      _serial(AccountSession.generation, () async {
        final credentials = await _load();
        return credentials?[key] as String?;
      });

  Future<String?> getToken() => _read('token');
  Future<String?> getUserId() => _read('userId');

  Future<void> clearAuth() {
    final generation = AccountSession.reset();
    return _serial(generation, () async {
      // Remove legacy fields first so a later read cannot resurrect them.
      await _removeLegacy(await SharedPreferences.getInstance());
      await _secure.delete(key: sessionKey);
    });
  }

  Future<void> clearToken() => clearAuth();
}
