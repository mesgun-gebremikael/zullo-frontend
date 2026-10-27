import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AuthStorage().clearAuth();
  });

  for (final register in [false, true]) {
    test('HTTP 429 exposes retry time without logging in (register=$register)',
        () async {
      var calls = 0;
      final auth = AuthService(client: MockClient((_) async {
        calls++;
        return http.Response('{"message":"Too many attempts"}', 429,
            headers: {'retry-after': '42'});
      }));
      final request = register
          ? auth.register(
              name: 'Test', email: 'user@example.test', password: 'password123')
          : auth.login(email: 'user@example.test', password: 'password123');
      await expectLater(
          request,
          throwsA(isA<AuthRateLimitException>()
              .having((e) => e.retryAfterSeconds, 'retry time', 42)));
      expect(calls, 1);
      expect(await AuthStorage().getToken(), isNull);
    });
  }

  test('missing or malformed retry header uses a safe default', () async {
    final auth = AuthService(
        client: MockClient((_) async =>
            http.Response('', 429, headers: {'retry-after': 'not-a-number'})));
    await expectLater(
        auth.login(email: 'user@example.test', password: 'password123'),
        throwsA(isA<AuthRateLimitException>()
            .having((e) => e.retryAfterSeconds, 'retry time', 60)));
  });
}
