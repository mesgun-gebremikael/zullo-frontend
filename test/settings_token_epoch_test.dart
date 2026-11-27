import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';

class SettingsDelayedToken extends AuthStorage {
  final pending = Completer<String?>();
  @override
  Future<String?> getToken() => pending.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'A-token', userId: 'A');
  });
  for (final readOnly in [true, false]) {
    test(
        'discovery token wait retains its original account when service logs into another $readOnly',
        () async {
      final storage = SettingsDelayedToken();
      int writes = 0;
      final auth = AuthService(
          storage: storage,
          pushTokenLoader: () async => null,
          client: MockClient((r) async {
            if (r.url.path.endsWith('/api/auth/login')) {
              return http.Response('{"userId":"B","token":"B-token"}', 200);
            }
            writes++;
            return http.Response('{}', 200);
          }));
      final old = auth.discoverySettings(
          update: readOnly ? null : {'automaticLocation': false});
      final denied = expectLater(old, throwsA(isA<SessionChangedException>()));
      await auth.login(email: 'b@example.test', password: 'Password123!');
      storage.pending.complete('A-token');
      await denied;
      expect(writes, 0);
    });
  }
  test('discovery update snapshots values before token read', () async {
    final storage = SettingsDelayedToken();
    Map<String, dynamic>? body;
    final auth = AuthService(
        storage: storage,
        client: MockClient((r) async {
          body = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }));
    final values = <String, dynamic>{'expandAge': false};
    final sent = auth.discoverySettings(update: values);
    values['expandAge'] = true;
    storage.pending.complete('A-token');
    await sent;
    expect(body, {'expandAge': false});
  });
}
