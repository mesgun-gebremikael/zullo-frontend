import 'package:zullo_app/l10n/presence_text.dart';
import 'package:zullo_app/l10n/app_localizations_sv.dart';
import 'package:zullo_app/models/swipe_profile.dart';
import 'package:zullo_app/widgets/swipe_profile_card.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/premium_page.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/commerce_service.dart';
import 'package:zullo_app/services/account_session.dart';

class FakeCommerce extends CommerceClient {
  CommerceState current = const CommerceState();
  int syncs = 0, boosts = 0;
  Completer<void>? pending;
  @override
  Future<CommerceState> state() async => current;
  @override
  Future<CommerceState> sync() async {
    syncs++;
    await pending?.future;
    return current = const CommerceState(checkoutEnabled: true, superLikes: 5);
  }

  @override
  Future<CommerceState> boost() async {
    boosts++;
    return current = CommerceState(
        boosts: 0, boostUntil: DateTime.now().add(const Duration(minutes: 30)));
  }
}

class FakeStore extends NativeBilling {
  int offerLoads = 0, buys = 0, restores = 0;
  bool failOffers = false;
  @override
  bool get available => true;
  @override
  Future<List<StoreOffer>> offers(String userId) async {
    offerLoads++;
    if (failOffers) throw StateError('store unavailable');
    return [
      const StoreOffer('zullo_superlikes_5', '5 Superlikes', '29,00 kr', 1)
    ];
  }

  @override
  Future<void> buy(StoreOffer offer, String userId) async {
    buys++;
  }

  @override
  Future<void> restore(String userId) async {
    restores++;
  }
}

class PrivacyCommerce extends FakeCommerce {
  @override
  Future<CommerceState> sync() async {
    syncs++;
    return current =
        const CommerceState(checkoutEnabled: true, activityPrivacy: true);
  }
}

class PrivacyStore extends FakeStore {
  @override
  Future<List<StoreOffer>> offers(String userId) async => const [
        StoreOffer(
            'zullo_hide_activity_monthly', 'Dölj aktivitet', '19,00 kr', 1),
        StoreOffer('zullo_premium_monthly', 'ZULLO Premium', '59,00 kr', 2),
        StoreOffer('zullo_boost_1', '1 Boost', '9,00 kr', 3),
      ];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'token', userId: 'account');
  });
  Future<void> pump(WidgetTester tester, Future<void> Function() action) async {
    await tester.runAsync(() async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
      'standalone activity page offers privacy and Premium without Boost upsell and verifies its own entitlement',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final commerce = PrivacyCommerce()
      ..current = const CommerceState(checkoutEnabled: true);
    final store = PrivacyStore();
    await pump(
        tester,
        () => tester.pumpWidget(MaterialApp(
            home: PremiumPage(
                commerce: commerce, billing: store, activityOnly: true))));
    expect(find.text('Bara Dölj aktivitet'), findsOneWidget);
    expect(find.text('19,00 kr per månad'), findsOneWidget);
    expect(find.text('1 Boost'), findsNothing);
    expect(find.text('Det här ingår i Premium'), findsNothing);
    await pump(tester, () async {
      await tester.tap(find.widgetWithText(FilledButton, 'Köp').first);
    });
    expect(store.buys, 1);
    expect(commerce.syncs, 1);
    expect(commerce.current.canHideActivity, isTrue);
    expect(commerce.current.premium, isFalse);
    expect(find.textContaining('väntar på verifiering'), findsNothing);
    final privacyButton = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Köp').first);
    expect(privacyButton.onPressed, isNull);
    await pump(tester, () => tester.pumpWidget(const SizedBox.shrink()));
  });

  testWidgets(
      'Premium already includes activity privacy and prevents a redundant standalone purchase',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final commerce = PrivacyCommerce()
      ..current = const CommerceState(checkoutEnabled: true, premium: true);
    await pump(
        tester,
        () => tester.pumpWidget(MaterialApp(
            home: PremiumPage(
                commerce: commerce,
                billing: PrivacyStore(),
                activityOnly: true))));
    expect(find.text('Dölj aktivitet ingår för dig'), findsOneWidget);
    for (final button in tester
        .widgetList<FilledButton>(find.widgetWithText(FilledButton, 'Köp'))) {
      expect(button.onPressed, isNull);
    }
    await pump(tester, () => tester.pumpWidget(const SizedBox.shrink()));
  });

  testWidgets(
      'unconfigured checkout shows balances but never queries or offers a purchase',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FakeStore();
    await pump(
        tester,
        () => tester.pumpWidget(MaterialApp(
            home: PremiumPage(commerce: FakeCommerce(), billing: store))));
    expect(store.offerLoads, 0);
    expect(find.text('Köp'), findsNothing);
    expect(find.textContaining('Köp är inte tillgängliga'), findsOneWidget);
    await pump(tester, () => tester.pumpWidget(const SizedBox()));
  });
  testWidgets(
      'price comes from store and purchase syncs server instead of granting locally',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FakeStore();
    final commerce = FakeCommerce()
      ..current = const CommerceState(checkoutEnabled: true);
    await pump(
        tester,
        () => tester.pumpWidget(MaterialApp(
            home: PremiumPage(commerce: commerce, billing: store))));
    expect(find.text('29,00 kr'), findsOneWidget);
    await tester.ensureVisible(find.text('Köp'));
    await pump(tester, () => tester.tap(find.text('Köp')));
    expect(store.buys, 1);
    expect(commerce.syncs, 1);
    expect(find.text('5'), findsOneWidget);
    await pump(tester, () => tester.pumpWidget(const SizedBox()));
  });
  testWidgets('restore still works if offerings cannot be loaded',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FakeStore()..failOffers = true;
    final commerce = FakeCommerce()
      ..current = const CommerceState(checkoutEnabled: true);
    await pump(
        tester,
        () => tester.pumpWidget(MaterialApp(
            home: PremiumPage(commerce: commerce, billing: store))));
    await tester.ensureVisible(find.text('Återställ köp'));
    await pump(tester, () => tester.tap(find.text('Återställ köp')));
    expect(store.restores, 1);
    expect(commerce.syncs, 1);
    await pump(tester, () => tester.pumpWidget(const SizedBox()));
  });
  testWidgets('active boost has countdown and cannot consume another credit',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final commerce = FakeCommerce()
      ..current = CommerceState(
          boosts: 1,
          boostUntil: DateTime.now().add(const Duration(minutes: 20)));
    await pump(
        tester,
        () => tester.pumpWidget(MaterialApp(
            home: PremiumPage(commerce: commerce, billing: FakeStore()))));
    final button = tester.widget<FilledButton>(find.byWidgetPredicate(
        (widget) => widget is FilledButton && widget.onPressed == null));
    expect(button.onPressed, isNull);
    expect(commerce.boosts, 0);
    await pump(tester, () => tester.pumpWidget(const SizedBox()));
  });
  testWidgets('recipient sees a distinct Superlike badge on the discovery card',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profile = SwipeProfile.fromJson({
      'userId': 'peer',
      'displayName': 'Anna',
      'age': 25,
      'photoUrls': [],
      'superLikedYou': true
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 400,
                    height: 700,
                    child: SwipeProfileCard(
                        profile: profile, width: 400, height: 700))))));
    await tester.pumpAndSettle();
    expect(find.text('Har supergillat dig'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('Superlike sends a distinct server operation', () async {
    final auth = AuthService(client: MockClient((request) async {
      expect(jsonDecode(request.body)['superLike'], isTrue);
      return http.Response('{"matched":false}', 200);
    }));
    expect(await auth.like('peer', superLike: true), isFalse);
  });
  test('relative activity uses minutes and days and hides missing timestamps',
      () {
    final now = DateTime.utc(2026, 11, 1, 12);
    expect(
        PresenceText.format(null, now: now, strings: AppLocalizationsSv()), '');
    expect(
        PresenceText.format(now.subtract(const Duration(seconds: 30)),
            now: now, strings: AppLocalizationsSv()),
        'Online nu');
    expect(
        PresenceText.format(now.subtract(const Duration(minutes: 4)),
            now: now, strings: AppLocalizationsSv()),
        'Senast aktiv för 4 minuter sedan');
    expect(
        PresenceText.format(now.subtract(const Duration(days: 3)),
            now: now, strings: AppLocalizationsSv()),
        'Senast aktiv för 3 dagar sedan');
  });
  test('account change rejects stale commerce balances', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final client = CommerceClient(client: MockClient((_) {
      started.complete();
      return pending.future;
    }));
    final request = client.state();
    final rejected =
        expectLater(request, throwsA(isA<SessionChangedException>()));
    await started.future;
    AccountSession.reset();
    pending.complete(http.Response('{"premium":true,"superLikes":100}', 200));
    await rejected;
  });
}
