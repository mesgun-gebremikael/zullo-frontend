import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/onboarding/onboarding_wizard.dart';
import 'package:zullo_app/onboarding/onboarding_data.dart';
import 'package:zullo_app/register_page.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/welcome_page.dart';

class NavigationAuth extends AuthService {
  String? token = 'onboarding-token';
  @override
  Future<void> logout() async {
    token = null;
    AccountSession.reset();
  }
}

class DelayedOnboardingLogout extends NavigationAuth {
  final finish = Completer<void>();
  int calls = 0;
  @override
  Future<void> logout() async {
    calls++;
    await super.logout();
    await finish.future;
  }
}

class RetryOnboardingLogout extends NavigationAuth {
  int attempts = 0;
  @override
  Future<void> logout() async {
    if (++attempts == 1) throw StateError('storage unavailable');
    await super.logout();
  }
}

void main() {
  late NavigationAuth currentAuth;
  setUp(() {
    AccountSession.reset();
    currentAuth = NavigationAuth();
  });
  void screen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  AuthService auth() => currentAuth;
  Future<void> settle(
      WidgetTester tester, Future<void> Function() action) async {
    await action();
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }

  Future<void> openExit(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Lämna profilskapandet'));
    await tester.pumpAndSettle();
  }

  for (final systemBack in [false, true]) {
    testWidgets(
        'first step confirms leaving and returns safely to welcome (system=$systemBack)',
        (tester) async {
      screen(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
          navigatorKey: navigator,
          home: OnboardingWizard(authService: auth())));
      if (systemBack) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      } else {
        await openExit(tester);
      }
      expect(find.text('Vill du lämna profilskapandet?'), findsOneWidget);
      expect(currentAuth.token, 'onboarding-token');
      await settle(tester, () async {
        await tester.tap(find.text('Lämna'));
      });
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
      expect(currentAuth.token, isNull);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterPage), findsOneWidget);
    });
  }
  testWidgets('cancel leaving keeps the name and authentication',
      (tester) async {
    screen(tester);
    final data = OnboardingData();
    await tester.pumpWidget(
        MaterialApp(home: OnboardingWizard(data: data, authService: auth())));
    await tester.enterText(find.byType(TextFormField), 'Anna');
    await openExit(tester);
    await tester.tap(find.text('Fortsätt'));
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    expect(currentAuth.token, 'onboarding-token');
    expect(find.byType(WelcomePage), findsNothing);
  });
  testWidgets('existing auth history is cleared after confirmed leave',
      (tester) async {
    screen(tester);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const WelcomePage()));
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => OnboardingWizard(authService: auth())));
    await tester.pumpAndSettle();
    await openExit(tester);
    await settle(tester, () async {
      await tester.tap(find.text('Lämna'));
    });
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
  });
  testWidgets('back from date preserves name and session', (tester) async {
    screen(tester);
    await tester
        .pumpWidget(MaterialApp(home: OnboardingWizard(authService: auth())));
    await tester.enterText(find.byType(TextFormField), 'Anna');
    await tester.pump();
    await tester.tap(find.text('Nästa'));
    await tester.pumpAndSettle();
    expect(find.text('När föddes du?'), findsOneWidget);
    await tester.tap(find.byTooltip('Tillbaka'));
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    expect(currentAuth.token, 'onboarding-token');
  });
  testWidgets('duplicate confirmed leave performs only one logout',
      (tester) async {
    screen(tester);
    final delayed = DelayedOnboardingLogout();
    await tester
        .pumpWidget(MaterialApp(home: OnboardingWizard(authService: delayed)));
    await openExit(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Lämna'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(delayed.calls, 1);
    delayed.finish.complete();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
  });
  testWidgets('logout failure keeps visible answers and supports retry',
      (tester) async {
    screen(tester);
    final retry = RetryOnboardingLogout();
    await tester
        .pumpWidget(MaterialApp(home: OnboardingWizard(authService: retry)));
    await openExit(tester);
    await settle(tester, () async {
      await tester.tap(find.text('Lämna'));
    });
    expect(find.text('Vad heter du i förnamn?'), findsOneWidget);
    expect(currentAuth.token, 'onboarding-token');
    await openExit(tester);
    await settle(tester, () async {
      await tester.tap(find.text('Lämna'));
    });
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(retry.attempts, 2);
  });
  testWidgets('old logout cannot replace newer account navigation',
      (tester) async {
    screen(tester);
    final delayed = DelayedOnboardingLogout();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator, home: OnboardingWizard(authService: delayed)));
    await openExit(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Lämna'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      AccountSession.reset();
      currentAuth.token = 'new-account-token';
    });
    navigator.currentState!.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('New session'))));
    delayed.finish.complete();
    await tester.pumpAndSettle();
    expect(find.text('New session'), findsOneWidget);
    expect(find.byType(WelcomePage), findsNothing);
    expect(currentAuth.token, 'new-account-token');
  });
}
