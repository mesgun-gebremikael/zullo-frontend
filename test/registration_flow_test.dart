import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/register_page.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
  });

  for (final register in [true, false]) {
    test('authentication saves identity and registers push (register=$register)', () async {
      final savedPush = Completer<void>();
      final paths = <String>[];
      final auth = AuthService(pushTokenLoader: () async => 'device-token',
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/me/device-token') {
            expect(request.headers['Authorization'], 'Bearer new-token');
            expect(jsonDecode(request.body), {'token': 'device-token'});
            savedPush.complete();
            return http.Response('{}', 200);
          }
          return http.Response('{"token":"new-token","userId":"new-user"}', 200);
        }));
      if (register) {
        await auth.registerAndLogin(name: 'Test', email: 'test@example.test', password: 'password123');
      } else {
        await auth.login(email: 'test@example.test', password: 'password123');
      }
      await savedPush.future;
      expect(paths, [register ? '/api/auth/register' : '/api/auth/login', '/me/device-token']);
      expect(await AuthStorage().getUserId(), 'new-user');
    });
  }

  test('delayed push token cannot attach to a different account', () async {
    final token = Completer<String?>();
    var pushCalls = 0;
    final auth = AuthService(pushTokenLoader: () => token.future,
      client: MockClient((request) async {
        if (request.url.path == '/me/device-token') pushCalls++;
        return http.Response('{"token":"A-token","userId":"A"}', 200);
      }));
    await auth.registerAndLogin(name: 'A', email: 'a@example.test', password: 'password123');
    await AuthStorage().saveAuth(token: 'B-token', userId: 'B');
    token.complete('old-device-token');
    await Future<void>.delayed(Duration.zero);
    expect(pushCalls, 0);
    expect(await AuthStorage().getUserId(), 'B');
  });

  test('push failure does not fail registration or automatic login', () async {
    final auth = AuthService(pushTokenLoader: () async => throw StateError('FCM offline'),
      client: MockClient((_) async => http.Response('{"token":"token","userId":"user"}', 200)));
    await auth.registerAndLogin(name: 'Test', email: 'test@example.test', password: 'password123');
    expect(await AuthStorage().getToken(), 'token');
  });

  testWidgets('double taps send one request and duplicate-email error stays visible', (tester) async {
    final response = Completer<http.Response>();
    var calls = 0;
    final auth = AuthService(client: MockClient((_) { calls++; return response.future; }));
    await tester.pumpWidget(MaterialApp(home: RegisterPage(authService: auth)));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Test');
    await tester.enterText(fields.at(1), 'test@example.test');
    await tester.enterText(fields.at(2), 'password123');
    final button = find.widgetWithText(ElevatedButton, 'Create account');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Skapar ditt konto…'), findsOneWidget);
    response.complete(http.Response('{"message":"User already exists."}', 400));
    await tester.pumpAndSettle();
    expect(find.text('E-postadressen används redan. Logga in i stället.'), findsOneWidget);
  });
}
