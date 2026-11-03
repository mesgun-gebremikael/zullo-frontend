import 'support/draft_fakes.dart';
import 'support/pump_platform_routes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/main_navigation.dart';
import 'package:zullo_app/onboarding/onboarding_start_page.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/splash_page.dart';

class StartupStorage extends AuthStorage {
  @override
  Future<String?> getToken() async => 'saved-token';
}

class StalledStorage extends AuthStorage {
  final pending = Completer<String?>();
  @override
  Future<String?> getToken() => pending.future;
}

void main() {
  setUp(AccountSession.reset);

  testWidgets('unresponsive profile request has its own finite deadline',
      (tester) async {
    final pending = Completer<http.Response>();
    final auth = AuthService(
        storage: StartupStorage(), client: MockClient((_) => pending.future));
    final operation = auth.hasProfile();
    final rejected = expectLater(operation, throwsA(isA<TimeoutException>()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
    await rejected;
    pending.complete(http.Response('{}', 200));
    await tester.pump();
  });

  testWidgets(
      'offline startup offers retry and ignores the first response arriving late',
      (tester) async {
    final pending = Completer<http.Response>();
    var attempts = 0;
    final storage = StartupStorage();
    final auth = RoutingAuth(
        storage: storage,
        client: MockClient((request) {
          if (request.url.path == '/me/onboarding') {
            return Future.value(http.Response('{}', 404));
          }
          attempts++;
          return attempts == 1
              ? pending.future
              : Future.value(http.Response('{}', 404));
        }));
    await tester.pumpWidget(MaterialApp(
        home: SplashPage(
      authService: auth,
      storage: storage,
      startupDelay: Duration.zero,
      checkTimeout: const Duration(seconds: 2),
    )));
    await tester.pump();
    expect(find.text('Öppnar appen…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(
        find.textContaining('Anslutningen tog för lång tid'), findsOneWidget);
    expect(find.text('Försök igen'), findsOneWidget);
    expect(await storage.getToken(), 'saved-token');
    expect(find.byType(OnboardingStartPage), findsNothing);
    await tester.tap(find.text('Försök igen'));
    await pumpPlatformRoutes(tester);
    expect(attempts, 2);
    expect(find.byType(OnboardingStartPage), findsOneWidget);
    pending.complete(http.Response('{}', 200));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingStartPage), findsOneWidget);
    expect(find.byType(MainNavigation), findsNothing);
  });

  testWidgets(
      'stalled device credential storage also exits the splash loading state',
      (tester) async {
    final storage = StalledStorage();
    await tester.pumpWidget(MaterialApp(
        home: SplashPage(
      storage: storage,
      startupDelay: Duration.zero,
      checkTimeout: const Duration(seconds: 2),
    )));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Försök igen'), findsOneWidget);
    storage.pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Försök igen'), findsOneWidget);
  });
}
