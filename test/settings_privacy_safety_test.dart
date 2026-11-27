import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/profile_settings_page.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/commerce_service.dart';

class SettingsInfoAuth extends AuthService {
  int loads = 0;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> getMyAccount() async {
    loads++;
    if (fail) throw StateError('offline');
    return {'email': 'owner@example.test'};
  }
}

class PrivacyCommerce extends CommerceClient {
  int loads = 0, saves = 0;
  bool fail = false;
  bool? hide, incognito;
  Completer<CommerceState>? loading, saving;
  CommerceState current =
      const CommerceState(premium: true, hideActivity: true);
  @override
  Future<CommerceState> state() {
    loads++;
    if (fail) return Future.error(StateError('offline'));
    return loading?.future ?? Future.value(current);
  }

  @override
  Future<CommerceState> privacy({bool? hideActivity, bool? incognito}) {
    saves++;
    hide = hideActivity;
    this.incognito = incognito;
    return saving?.future ?? Future.value(current);
  }
}

class PrivacyToken extends AuthStorage {
  @override
  Future<String?> getToken() async => 'token';
}

void main() {
  testWidgets(
      'privacy stays locked until verified and a toggle never sends its neighbor flag',
      (tester) async {
    final commerce = PrivacyCommerce()..loading = Completer();
    await tester.pumpWidget(MaterialApp(
        home: ProfileSettingsPage(
            authService: SettingsInfoAuth(), commerce: commerce)));
    await tester.pump();
    expect(find.byType(Switch), findsNothing);
    commerce.loading!.complete(commerce.current);
    await tester.pumpAndSettle();
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches[0].value,
        isFalse); // Hidden activity is the confirmed server value.
    commerce.saving = Completer();
    switches[1].onChanged!(true);
    await tester.pump();
    expect(commerce.saves, 1);
    expect(commerce.hide, isNull);
    expect(commerce.incognito, isTrue);
    expect(
        tester
            .widgetList<Switch>(find.byType(Switch))
            .every((w) => w.onChanged == null),
        isTrue);
    commerce.saving!.complete(const CommerceState(
        premium: true, hideActivity: true, incognito: true));
    await tester.pumpAndSettle();
    expect(tester.widgetList<Switch>(find.byType(Switch)).map((w) => w.value),
        [false, true]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'privacy offline failure provides retry without allowing default writes',
      (tester) async {
    final commerce = PrivacyCommerce()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: ProfileSettingsPage(
            authService: SettingsInfoAuth(), commerce: commerce)));
    await tester.pumpAndSettle();
    expect(find.text('Försök igen'), findsOneWidget);
    expect(
        tester
            .widgetList<Switch>(find.byType(Switch))
            .every((w) => w.onChanged == null),
        isTrue);
    commerce.fail = false;
    await tester.tap(find.text('Försök igen'));
    await tester.pumpAndSettle();
    expect(commerce.loads, 2);
    expect(find.text('Försök igen'), findsNothing);
    expect(
        tester
            .widgetList<Switch>(find.byType(Switch))
            .every((w) => w.onChanged != null),
        isTrue);
  });
  testWidgets(
      'settings immediately stop displaying old account details after account switch',
      (tester) async {
    final commerce = PrivacyCommerce();
    await tester.pumpWidget(MaterialApp(
        home: ProfileSettingsPage(
            authService: SettingsInfoAuth(), commerce: commerce)));
    await tester.pumpAndSettle();
    AccountSession.reset();
    await tester.pumpWidget(MaterialApp(
        home: ProfileSettingsPage(
            authService: SettingsInfoAuth(), commerce: commerce)));
    await tester.pump();
    expect(find.byType(Switch), findsNothing);
    expect(find.text('owner@example.test'), findsNothing);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
        'notification row opens OS settings once and reports failures $platform',
        (tester) async {
      var launches = 0;
      final result = Completer<bool>();
      await tester.pumpWidget(MaterialApp(
          home: ProfileSettingsPage(
              authService: SettingsInfoAuth(),
              commerce: PrivacyCommerce(),
              openSystemSettings: () {
                launches++;
                return result.future;
              })));
      await tester.pumpAndSettle();
      final entry = find.byIcon(Icons.notifications_outlined);
      expect(entry, findsOneWidget);
      await tester.tap(entry);
      await tester.tap(entry);
      expect(launches, 1);
      result.complete(false);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }
  testWidgets('failed account email can be retried and old error disappears',
      (tester) async {
    final auth = SettingsInfoAuth()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: ProfileSettingsPage(
            authService: auth, commerce: PrivacyCommerce())));
    await tester.pumpAndSettle();
    final error = find.textContaining('Kunde inte hämta kontot');
    // Locate the actionable email row even when lower on a compact phone.
    await tester.scrollUntilVisible(find.byIcon(Icons.alternate_email), 250);
    expect(error, findsOneWidget);
    auth.fail = false;
    await tester.tap(find.byIcon(Icons.alternate_email));
    await tester.pumpAndSettle();
    expect(find.text('owner@example.test'), findsOneWidget);
    expect(error, findsNothing);
    expect(auth.loads, 2);
  });
  test('privacy request emits only explicitly modified fields', () async {
    Map<String, dynamic>? submitted;
    final service = CommerceClient(
        storage: PrivacyToken(),
        client: MockClient((r) async {
          submitted = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }));
    await service.privacy(incognito: true);
    expect(submitted, {'incognito': true});
    await service.privacy(hideActivity: false);
    expect(submitted, {'hideActivity': false});
  });
}
