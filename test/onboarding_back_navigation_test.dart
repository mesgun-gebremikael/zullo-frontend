import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/onboarding/onboarding_birthdate_page.dart';
import 'package:zullo_app/onboarding/onboarding_name_page.dart';
import 'package:zullo_app/onboarding/onboarding_shell.dart';
import 'package:zullo_app/onboarding/onboarding_start_page.dart';
import 'package:zullo_app/register_page.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/welcome_page.dart';

class DelayedOnboardingLogout extends AuthService {
  final finish = Completer<void>();
  int calls = 0;
  @override
  Future<void> logout() async {
    calls++;
    await AuthStorage().clearAuth();
    await finish.future;
  }
}

class RetryOnboardingLogout extends AuthService {
  int attempts = 0;
  @override
  Future<void> logout() async {
    if (++attempts == 1) throw StateError('storage unavailable');
    await AuthStorage().clearAuth();
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'onboarding-token', userId: 'new-user');
  });
  void screen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  AuthService auth() => AuthService(client: MockClient((request) async {
        expect(request.url.path, '/me/device-token/clear');
        return http.Response('{}', 200); // Never call account deletion.
      }));
  Future<void> settleAsync(
      WidgetTester tester, Future<void> Function() action) async {
    await tester.runAsync(() async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  for (final systemBack in [false, true]) {
    testWidgets(
        'cold-start onboarding returns to welcome with back (system=$systemBack)',
        (tester) async {
      screen(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
          navigatorKey: navigator,
          home: OnboardingStartPage(authService: auth())));
      await settleAsync(tester, () async {
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip('Tillbaka'));
        }
      });
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
      expect(await tester.runAsync(() => AuthStorage().getToken()), isNull);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterPage), findsOneWidget);
    });
  }

  testWidgets('welcome below onboarding is replaced by one clean welcome route',
      (tester) async {
    screen(tester);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const WelcomePage()));
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => OnboardingStartPage(authService: auth())));
    await tester.pumpAndSettle();
    await settleAsync(tester, () async {
      await tester.tap(find.byTooltip('Tillbaka'));
    });
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back from birthdate preserves the name and signed-in session',
      (tester) async {
    screen(tester);
    await tester.pumpWidget(
        MaterialApp(home: OnboardingStartPage(authService: auth())));
    await tester.enterText(find.byType(TextField), 'Anna');
    await tester.pump();
    await tester.tap(find.text('Nästa'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingBirthdatePage), findsOneWidget);
    await tester.tap(find.byTooltip('Tillbaka'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingNamePage), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(await tester.runAsync(() => AuthStorage().getToken()),
        'onboarding-token');
  });

  testWidgets(
      'repeated first-step back taps perform one logout and cannot remove the last route',
      (tester) async {
    screen(tester);
    final delayed = DelayedOnboardingLogout();
    await tester.pumpWidget(
        MaterialApp(home: OnboardingStartPage(authService: delayed)));
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Tillbaka'));
      await tester.tap(find.byTooltip('Tillbaka'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(delayed.calls, 1);
    expect(find.byType(OnboardingNamePage), findsOneWidget);
    delayed.finish.complete();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed logout keeps a visible page and back can be retried',
      (tester) async {
    screen(tester);
    final retry = RetryOnboardingLogout();
    await tester
        .pumpWidget(MaterialApp(home: OnboardingStartPage(authService: retry)));
    await settleAsync(tester, () async {
      await tester.tap(find.byTooltip('Tillbaka'));
    });
    expect(find.byType(OnboardingNamePage), findsOneWidget);
    expect(find.text('Kunde inte återgå till startsidan. Försök igen.'),
        findsOneWidget);
    expect(await tester.runAsync(() => AuthStorage().getToken()),
        'onboarding-token');
    await settleAsync(tester, () async {
      await tester.tap(find.byTooltip('Tillbaka'));
    });
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(retry.attempts, 2);
  });

  testWidgets(
      'old onboarding logout cannot navigate over a newer signed-in account',
      (tester) async {
    screen(tester);
    final delayed = DelayedOnboardingLogout();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: OnboardingStartPage(authService: delayed)));
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Tillbaka'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await AuthStorage()
          .saveAuth(token: 'new-account-token', userId: 'other-user');
    });
    navigator.currentState!.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('New session'))));
    delayed.finish.complete();
    await tester.pumpAndSettle();
    expect(find.text('New session'), findsOneWidget);
    expect(find.byType(WelcomePage), findsNothing);
    expect(await tester.runAsync(() => AuthStorage().getToken()),
        'new-account-token');
    expect(tester.takeException(), isNull);
  });

  testWidgets('generic onboarding shell does not pop an isolated root route',
      (tester) async {
    screen(tester);
    await tester.pumpWidget(const MaterialApp(
        home: OnboardingShell(
            progress: 0.1, title: 'Step', subtitle: '', child: SizedBox())));
    await tester.tap(find.byTooltip('Tillbaka'));
    await tester.pumpAndSettle();
    expect(find.text('Step'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
