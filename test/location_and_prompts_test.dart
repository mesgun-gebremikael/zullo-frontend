import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/discovery_location_page.dart';
import 'package:zullo_app/onboarding/onboarding_data.dart';
import 'package:zullo_app/onboarding/onboarding_steps.dart';
import 'package:zullo_app/onboarding/onboarding_wizard.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/device_location_service.dart';
import 'package:zullo_app/theme/zullo_theme.dart';

class LocationAuth extends AuthService {
  Map<String, dynamic> value = {
    'automaticLocation': false,
    'locationName': '',
    'expandDistance': false,
    'expandAge': false,
    'radiusKm': 50,
    'minAge': 18,
    'maxAge': 99
  };
  final writes = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> discoverySettings(
      {Map<String, dynamic>? update}) async {
    if (update != null) {
      writes.add(Map.from(update));
      value.addAll(update);
      value['locationChanged'] = update.containsKey('lat');
    }
    return Map.from(value);
  }
}

class FakePlace extends DeviceLocationService {
  bool denied = false;
  final requests = <bool>[];
  Completer<DevicePlace?>? pending;
  @override
  Future<DevicePlace?> locate({required bool requestPermission}) async {
    requests.add(requestPermission);
    if (denied) {
      throw const LocationFailure('Tillåt plats i telefonens inställningar.');
    }
    return pending?.future ??
        const DevicePlace(40.4168, -3.7038, 'Madrid, Spanien');
  }
}

class TokenStorage extends AuthStorage {
  @override
  Future<String?> getToken() async => 'token';
}

void main() {
  test('foreground location is opt-in, throttled and never asks for permission',
      () async {
    final auth = LocationAuth(), place = FakePlace();
    expect(
        await ForegroundLocationSync(auth, location: place).refresh(), isFalse);
    expect(place.requests, isEmpty);
    auth.value['automaticLocation'] = true;
    final sync = ForegroundLocationSync(auth, location: place);
    expect(await sync.refresh(), isTrue);
    expect(await sync.refresh(), isFalse);
    expect(place.requests, [false]);
    expect(auth.writes.single['lat'], 40.4168);
  });
  test('late GPS result after account switch cannot save a location', () async {
    final auth = LocationAuth()..value['automaticLocation'] = true;
    final place = FakePlace()..pending = Completer<DevicePlace?>();
    final result = ForegroundLocationSync(auth, location: place).refresh();
    await Future<void>.delayed(Duration.zero);
    AccountSession.reset();
    place.pending!.complete(const DevicePlace(40, -3, 'Madrid'));
    expect(await result, isFalse);
    expect(auth.writes, isEmpty);
  });
  test('backgrounding during a GPS read prevents the location write', () async {
    var foreground = true;
    final auth = LocationAuth()..value['automaticLocation'] = true;
    final place = FakePlace()..pending = Completer<DevicePlace?>();
    final result = ForegroundLocationSync(auth, location: place, isActive: () => foreground).refresh();
    await Future<void>.delayed(Duration.zero);
    foreground = false;
    place.pending!.complete(const DevicePlace(40, -3, 'Madrid'));
    expect(await result, isFalse); expect(auth.writes, isEmpty);
  });
  testWidgets(
      'location permission failure keeps settings usable and does not save fake coordinates',
      (tester) async {
    final auth = LocationAuth(), place = FakePlace()..denied = true;
    await tester.pumpWidget(MaterialApp(
        theme: zulloTheme(),
        home:
            DiscoveryLocationPage(authService: auth, locationService: place)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uppdatera min plats'));
    await tester.pumpAndSettle();
    expect(
        find.text('Tillåt plats i telefonens inställningar.'), findsOneWidget);
    expect(auth.writes, isEmpty);
    place.denied = false;
    await tester.tap(find.text('Uppdatera min plats'));
    await tester.pumpAndSettle();
    expect(find.text('Madrid, Spanien'), findsOneWidget);
    expect(auth.writes.single['automaticLocation'], isTrue);
    expect(place.requests, [true, true]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'optional prompt can be answered, restored and skipped without an invalid half-answer',
      (tester) async {
    final data = OnboardingData()
      ..promptKey = 'ask_me'
      ..promptAnswer = 'Min trädgård';
    final restored = OnboardingData.fromDraft(data.toDraft());
    expect(restored.promptAnswer, 'Min trädgård');
    await tester.pumpWidget(MaterialApp(
        home:
            OnboardingWizard(data: restored, initialStep: OnboardingStep.bio)));
    await tester.pumpAndSettle();
    expect(find.text('Min trädgård'), findsOneWidget);
    await tester.ensureVisible(find.text('Ta bort samtalsfrågan'));
    await tester.tap(find.text('Ta bort samtalsfrågan'));
    await tester.pumpAndSettle();
    expect(restored.promptKey, isEmpty);
    expect(restored.promptAnswer, isEmpty);
    await tester.ensureVisible(find.text('Hoppa över'));
    await tester.tap(find.text('Hoppa över'));
    await tester.pumpAndSettle();
    expect(find.text('Lägg till dina bilder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('matched profile and discovery requests use account-scoped endpoints',
      () async {
    final auth = AuthService(
        storage: TokenStorage(),
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token');
          if (request.url.path == '/profiles/B') {
            return http.Response(
                '{"userId":"B","photoUrls":["one","two"],"promptKey":"weekend","promptAnswer":"Havet"}',
                200);
          }
          expect(request.url.path, '/me/discovery-settings');
          expect(jsonDecode(request.body)['expandDistance'], true);
          return http.Response('{"expandDistance":true}', 200);
        }));
    expect((await auth.getMatchedProfile('B')).photoUrls.length, 2);
    expect(
        (await auth.discoverySettings(
            update: {'expandDistance': true}))['expandDistance'],
        true);
  });
  test('global theme uses white menus and cool neutral surfaces', () {
    final theme = zulloTheme();
    expect(theme.popupMenuTheme.color, Colors.white);
    expect(theme.dialogTheme.backgroundColor, Colors.white);
    expect(theme.colorScheme.surfaceContainerHighest, const Color(0xFFF0F2F6));
    expect(theme.colorScheme.primary, const Color(0xFFEC2863));
  });
}
