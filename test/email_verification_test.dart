import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/email_verification_page.dart';
import 'package:zullo_app/models/email_address_validation.dart';
import 'package:zullo_app/register_page.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';

Map<String, String> challengeJson({String id = 'challenge'}) => {
      'challengeId': id,
      'email': 'person@example.test',
      'expiresAtUtc': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 15))
          .toIso8601String(),
      'nextSendAtUtc': DateTime.now().toUtc().toIso8601String()
    };
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AuthStorage().clearAuth();
  });
  test(
      'new register and pending login have no auth identity until server verifies code',
      () async {
    var verified = false;
    final auth = AuthService(
        pushTokenLoader: () async => null,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/verify-email')) {
            expect(jsonDecode(request.body)['code'], '123456');
            verified = true;
            return http.Response(
                '{"token":"verified-token","userId":"verified-user"}', 200);
          }
          return http.Response(jsonEncode(challengeJson()), 202);
        }));
    for (final register in [true, false]) {
      await expectLater(
          register
              ? auth.registerAndLogin(
                  email: 'person@example.test', password: 'password123')
              : auth.login(
                  email: 'person@example.test', password: 'password123'),
          throwsA(isA<EmailVerificationRequired>()));
      expect(await AuthStorage().getToken(), isNull);
    }
    await auth.verifyEmail(
        EmailVerificationChallenge.fromJson(challengeJson()), '123456');
    expect(verified, isTrue);
    expect(await AuthStorage().getUserId(), 'verified-user');
  });
  test('late verification cannot sign in after session reset', () async {
    final response = Completer<http.Response>();
    final auth = AuthService(
        pushTokenLoader: () async => null,
        client: MockClient((_) => response.future));
    final pending = auth.verifyEmail(
        EmailVerificationChallenge.fromJson(challengeJson()), '123456');
    AccountSession.reset();
    response.complete(
        http.Response('{"token":"old-token","userId":"old-user"}', 200));
    await expectLater(pending, throwsA(isA<SessionChangedException>()));
    expect(await AuthStorage().getToken(), isNull);
  });
  test(
      'syntax and typo suggestion do not silently change legitimate custom providers',
      () {
    expect(EmailAddressValidation.isValid('a+b@sub.example.org'), isTrue);
    for (final invalid in [
      'garbage',
      'a@localhost',
      'a..b@gmail.com',
      'a@-example.com',
      'a@b.com\r\nBcc:c@d.com'
    ]) {
      expect(EmailAddressValidation.isValid(invalid), isFalse, reason: invalid);
    }
    expect(
        EmailAddressValidation.suggestedAddress('a@gmail.ocm'), 'a@gmail.com');
    expect(EmailAddressValidation.suggestedAddress('a@custom.example'), isNull);
  });
  testWidgets(
      'registration routes pending challenge to email form without onboarding',
      (tester) async {
    final auth = AuthService(
        pushTokenLoader: () async => null,
        client: MockClient(
            (_) async => http.Response(jsonEncode(challengeJson()), 202)));
    await tester.pumpWidget(MaterialApp(home: RegisterPage(authService: auth)));
    await tester.enterText(find.byType(TextField).at(0), 'person@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Skapa konto'));
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Skapa konto'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.byType(EmailVerificationPage), findsOneWidget);
    expect(await tester.runAsync(() => AuthStorage().getToken()), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'bad verification code stays on form; server provider errors never become credentials',
      (tester) async {
    var calls = 0;
    final auth = AuthService(client: MockClient((_) async {
      calls++;
      return http.Response('{"code":"verification_invalid"}', 400);
    }));
    await tester.pumpWidget(MaterialApp(
        home: EmailVerificationPage(
            challenge: EmailVerificationChallenge.fromJson(challengeJson()),
            authService: auth)));
    await tester.enterText(
        find.byKey(const ValueKey('email-verification-code')), '123456');
    await tester.runAsync(() async {
      await tester
          .tap(find.widgetWithText(FilledButton, 'Bekräfta e-postadress'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Koden är felaktig eller har gått ut. Begär en ny kod.'),
        findsOneWidget);
    expect(await tester.runAsync(() => AuthStorage().getToken()), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
