import 'package:zullo_app/edit_profile_page.dart';
import 'package:zullo_app/onboarding/onboarding_interested_in_page.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/onboarding/onboarding_data.dart';
import 'package:zullo_app/onboarding/onboarding_start_page.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/splash_page.dart';
import 'package:zullo_app/welcome_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'A-token', userId: 'A');
  });

  Future<void> saveBasic(AuthService auth, {bool clearHeight = false}) =>
      auth.saveProfile(
          displayName: 'Anna',
          age: 29,
          gender: 'Kvinna',
          bio: 'Bio',
          photoUrls: ['https://images.example/a', 'https://images.example/b'],
          interests: ['Musik'],
          intention: 'Relationship',
          religion: 'Kristen',
          workout: 'Ofta',
          smoking: 'Nej',
          pets: 'Har husdjur',
          clearHeight: clearHeight);

  test('filter settings use one PATCH containing only changed fields',
      () async {
    var calls = 0;
    final auth = AuthService(client: MockClient((request) async {
      calls++;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/me/profile');
      expect(request.headers['Authorization'], 'Bearer A-token');
      expect(jsonDecode(request.body),
          {'intention': 'Date', 'religion': 'Muslim', 'matchRadiusKm': 300});
      return http.Response('{}', 200);
    }));
    await auth.updateFilterProfile(
        intention: 'Date', religion: 'Muslim', matchRadiusKm: 300);
    expect(calls, 1); // No GET/read-modify-write or separate radius request.
  });

  test('older save callers omit unprovided fields and geographic coordinates',
      () async {
    final auth = AuthService(client: MockClient((request) async {
      final data = jsonDecode(request.body) as Map;
      for (final field in [
        'heightCm',
        'lat',
        'lng',
        'countryCode',
        'workPlace',
        'childrenCount',
        'alcohol',
        'cannabis',
        'interestedIn',
        'matchRadiusKm'
      ]) {
        expect(data.containsKey(field), isFalse, reason: field);
      }
      expect(data['workout'], 'Ofta');
      expect(data['smoking'], 'Nej');
      return http.Response('{}', 200);
    }));
    await saveBasic(auth);
  });

  test('explicit clear of nullable height is sent as null', () async {
    final auth = AuthService(client: MockClient((request) async {
      final data = jsonDecode(request.body) as Map;
      expect(data.containsKey('heightCm'), isTrue);
      expect(data['heightCm'], isNull);
      return http.Response('{}', 200);
    }));
    await saveBasic(auth, clearHeight: true);
  });

  test(
      'onboarding transmits collected data including Swedish values and discovery settings',
      () async {
    final data = OnboardingData()
      ..displayName = 'Anna'
      ..birthDate = DateTime(2000, 10, 29)
      ..gender = 'Kvinna'
      ..interestedIn = 'Män'
      ..distanceKm = 300
      ..bio = 'Min bio'
      ..photoUrls = ['https://images.example/a', 'https://images.example/b']
      ..intention = 'Relationship'
      ..religion = 'Kristen'
      ..workout = 'Ofta'
      ..smoking = 'Nej'
      ..pets = 'Har husdjur'
      ..heightCm = 175
      ..relationshipHistory = 'Varit i ett förhållande'
      ..zodiacSign = 'Våg'
      ..childrenCount = '1 barn'
      ..wantChildren = 'Inte säker än'
      ..workStatus = 'Jobbar'
      ..studyPlace = 'Universitet'
      ..studySubject = 'Medicin'
      ..workPlace = 'Sjukhus'
      ..jobTitle = 'Läkare'
      ..livePlace = 'Stockholm'
      ..originPlace = 'Asmara';
    final expected = data.toProfileUpdate(today: DateTime(2026, 10, 28));
    expect(expected['age'], 25);
    expect(expected['interestedIn'], 'Män');
    expect(expected['matchRadiusKm'], 300);
    expect(expected['workout'], 'Ofta');
    expect(expected.containsKey('lat'), isFalse); // No fabricated coordinates.
    final auth = AuthService(client: MockClient((request) async {
      expect(jsonDecode(request.body), expected);
      return http.Response('{}', 200);
    }));
    await auth.saveOnboardingProfile(data, today: DateTime(2026, 10, 28));
    expect(data.toProfileUpdate(today: DateTime(2026, 10, 29))['age'], 26);
  });

  test('missing birthdate and underage onboarding cannot issue a save',
      () async {
    var calls = 0;
    final auth = AuthService(client: MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    }));
    expect(
        () => auth.saveOnboardingProfile(OnboardingData()), throwsStateError);
    expect(
        () => auth.saveOnboardingProfile(
            OnboardingData()..birthDate = DateTime(2010),
            today: DateTime(2026, 10, 28)),
        throwsStateError);
    expect(calls, 0);
  });

  for (final code in [200, 404, 401, 500]) {
    test('profile existence distinguishes HTTP $code', () async {
      final auth = AuthService(
          client: MockClient((_) async => http.Response('{}', code)));
      if (code == 200 || code == 404) {
        expect(await auth.hasProfile(), code == 200);
      } else {
        await expectLater(
            auth.hasProfile(),
            throwsA(code == 401
                ? isA<ProfileSessionExpiredException>()
                : isA<Exception>()));
      }
      expect(await AuthStorage().getToken(), 'A-token');
    });
  }

  test(
      'filter save returning after account switch cannot affect the new account',
      () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final auth = AuthService(client: MockClient((_) {
      started.complete();
      return response.future;
    }));
    final save =
        auth.updateFilterProfile(intention: 'Date', religion: 'Kristen');
    final assertion =
        expectLater(save, throwsA(isA<SessionChangedException>()));
    await started.future;
    await AuthStorage().saveAuth(token: 'B-token', userId: 'B');
    response.complete(http.Response('{}', 200));
    await assertion;
    expect(await AuthStorage().getUserId(), 'B');
  });

  testWidgets('onboarding restores the existing discovery choice',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = OnboardingData()..interestedIn = 'Män';
    await tester
        .pumpWidget(MaterialApp(home: OnboardingInterestedInPage(data: data)));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('Kvinnor'));
    await tester.tap(find.text('Nästa'));
    await tester.pumpAndSettle();
    expect(data.interestedIn, 'Kvinnor');
  });

  testWidgets(
      'profile editor retains discovery choice and does not invent a missing height',
      (tester) async {
    final auth = AuthService(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'displayName': 'Anna',
              'age': 29,
              'gender': 'Kvinna',
              'interestedIn': 'Män',
              'heightCm': null,
              'photoUrls': [],
              'workout': 'Ofta',
              'smoking': 'Nej',
            }),
            200)));
    await tester.runAsync(() async {
      await tester
          .pumpWidget(MaterialApp(home: EditProfilePage(authService: auth)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Män'))
            .selected,
        isTrue);
    expect(find.text('Ej angivet'), findsOneWidget);
    expect(find.textContaining('170 cm'), findsNothing);
  });

  testWidgets(
      'temporary profile lookup failure offers retry without logout or onboarding',
      (tester) async {
    var attempts = 0;
    final auth = AuthService(
        client: MockClient(
            (_) async => http.Response('{}', ++attempts == 1 ? 500 : 404)));
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
          home: SplashPage(authService: auth, startupDelay: Duration.zero)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('Försök igen'), findsOneWidget);
    expect(find.byType(OnboardingStartPage), findsNothing);
    expect(await tester.runAsync(() => AuthStorage().getToken()), 'A-token');
    await tester.runAsync(() async {
      await tester.tap(find.text('Försök igen'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingStartPage), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('expired session is cleared and returns to welcome',
      (tester) async {
    final auth =
        AuthService(client: MockClient((_) async => http.Response('{}', 401)));
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
          home: SplashPage(authService: auth, startupDelay: Duration.zero)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(await tester.runAsync(() => AuthStorage().getToken()), isNull);
  });
}
