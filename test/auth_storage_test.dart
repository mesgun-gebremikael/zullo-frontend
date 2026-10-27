import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = FlutterSecureStorage();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AuthStorage().clearAuth();
  });

  void legacy({String? token = 'old-token', String? userId = 'A'}) {
    SharedPreferences.setMockInitialValues({
      if (token != null) 'auth_token': token,
      if (userId != null) 'auth_user_id': userId,
      'theme': 'dark',
    });
  }

  Future<void> expectNoLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('auth_token'), isFalse);
    expect(prefs.containsKey('auth_user_id'), isFalse);
    expect(prefs.getString('theme'), 'dark');
  }

  test(
      'new credentials are a single secure record, never plaintext preferences',
      () async {
    legacy(token: null, userId: null);
    final storage = AuthStorage();
    await storage.saveAuth(token: 'new-token', userId: 'B');
    final record =
        jsonDecode((await secure.read(key: AuthStorage.sessionKey))!);
    expect(record, {'token': 'new-token', 'userId': 'B'});
    await expectNoLegacy();
    expect(await AuthStorage().getToken(), 'new-token');
    expect(await AuthStorage().getUserId(), 'B');
  });

  test('existing complete identity migrates and plaintext is removed',
      () async {
    legacy();
    final storage = AuthStorage();
    expect(await storage.getToken(), 'old-token');
    expect(await AuthStorage().getUserId(), 'A');
    await expectNoLegacy();
    expect(jsonDecode((await secure.read(key: AuthStorage.sessionKey))!),
        {'token': 'old-token', 'userId': 'A'});
  });

  for (final missing in ['token', 'userId', 'empty']) {
    test('incomplete legacy identity is discarded: $missing', () async {
      legacy(
          token: missing == 'token'
              ? null
              : missing == 'empty'
                  ? ''
                  : 'old-token',
          userId: missing == 'userId' ? null : 'A');
      final storage = AuthStorage();
      expect(await storage.getToken(), isNull);
      expect(await storage.getUserId(), isNull);
      expect(await secure.read(key: AuthStorage.sessionKey), isNull);
      await expectNoLegacy();
    });
  }

  test('secure identity takes precedence over leftover legacy identity',
      () async {
    legacy();
    await secure.write(
        key: AuthStorage.sessionKey,
        value: jsonEncode({'token': 'B-token', 'userId': 'B'}));
    expect(await AuthStorage().getToken(), 'B-token');
    expect(await AuthStorage().getUserId(), 'B');
    await expectNoLegacy();
  });

  for (final record in ['not-json', '{"token":"A"}', '[]']) {
    test(
        'corrupt secure identity never falls back to a legacy account: $record',
        () async {
      legacy();
      await secure.write(key: AuthStorage.sessionKey, value: record);
      expect(await AuthStorage().getToken(), isNull);
      expect(await AuthStorage().getUserId(), isNull);
      expect(await secure.read(key: AuthStorage.sessionKey), isNull);
      await expectNoLegacy();
    });
  }

  test('logout deletes both stores without deleting unrelated preferences',
      () async {
    legacy();
    await secure.write(
        key: AuthStorage.sessionKey,
        value: jsonEncode({'token': 'B-token', 'userId': 'B'}));
    await AuthStorage().clearAuth();
    expect(await secure.read(key: AuthStorage.sessionKey), isNull);
    expect(await AuthStorage().getToken(), isNull);
    await expectNoLegacy();
  });

  test('secure storage read failure does not expose legacy credentials',
      () async {
    legacy();
    final secure = _ControlledStorage()..failRead = true;
    await expectLater(AuthStorage(secureStorage: secure).getToken(),
        throwsA(isA<PlatformException>()));
  });

  test(
      'failed migration does not delete the only copy and can be retried safely',
      () async {
    legacy();
    final secure = _ControlledStorage()..failWrite = true;
    final storage = AuthStorage(secureStorage: secure);
    await expectLater(storage.getToken(), throwsA(isA<PlatformException>()));
    expect((await SharedPreferences.getInstance()).getString('auth_token'),
        'old-token');
    secure.failWrite = false;
    expect(await storage.getToken(), 'old-token');
    await expectNoLegacy();
  });

  test('logout during migration invalidates the read and prevents resurrection',
      () async {
    legacy();
    final secure = _ControlledStorage()..writeGate = Completer<void>();
    final storage = AuthStorage(secureStorage: secure);
    final read = storage.getToken();
    final rejected = expectLater(read, throwsA(isA<SessionChangedException>()));
    await secure.writeStarted.future;
    final logout = storage.clearAuth();
    secure.writeGate!.complete();
    await rejected;
    await logout;
    expect(await AuthStorage().getToken(), isNull);
    expect(
        await FlutterSecureStorage().read(key: AuthStorage.sessionKey), isNull);
  });
}

class _ControlledStorage extends FlutterSecureStorage {
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? writeGate;
  final writeStarted = Completer<void>();

  @override
  Future<String?> read(
      {required String key,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) {
    if (failRead) throw PlatformException(code: 'locked');
    return super.read(key: key);
  }

  @override
  Future<void> write(
      {required String key,
      required String? value,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    if (failWrite) throw PlatformException(code: 'unavailable');
    if (writeGate != null) {
      if (!writeStarted.isCompleted) writeStarted.complete();
      await writeGate!.future;
    }
    await super.write(key: key, value: value);
  }
}
