import 'package:purchases_flutter/purchases_flutter.dart' show StoreTransaction;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/premium_page.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/commerce_service.dart';
import 'package:zullo_app/services/pending_store_purchase.dart';

class _Commerce extends CommerceClient {
  CommerceState current = const CommerceState(checkoutEnabled: true);
  bool verified = true, refunded = false;
  int checks = 0;
  StorePurchase? lastReceipt;
  @override
  Future<CommerceState> state() async => current;
  @override
  Future<CommerceState> sync() async => current;
  @override
  Future<({bool verified, bool refunded})> purchaseStatus(
      StorePurchase receipt) async {
    checks++;
    lastReceipt = receipt;
    return (verified: verified, refunded: refunded);
  }
}

class _Store extends NativeBilling {
  int buys = 0;
  Object? failure;
  List<StorePurchase> history = [];
  final bool plans;
  _Store({this.plans = false});
  @override
  bool get available => true;
  @override
  Future<List<StoreOffer>> offers(String userId) async => plans
      ? const [
          StoreOffer('zullo_premium_monthly', 'Native monthly', '59,00 kr', 1),
          StoreOffer('zullo_premium_annual', 'Native yearly', '499,00 kr', 2),
          StoreOffer(
              'zullo_hide_activity_monthly', 'Legacy privacy', '19,00 kr', 3),
        ]
      : const [StoreOffer('zullo_superlikes_5', '5 Superlikes', '29,00 kr', 1)];
  @override
  Future<StorePurchase> buy(StoreOffer offer, String userId) async {
    buys++;
    if (failure != null) throw failure!;
    return StorePurchase('app_store', 'exact-transaction', offer.id,
        purchaseDate: DateTime.now().toUtc());
  }

  @override
  Future<List<StorePurchase>> recentPurchases(String userId) async => history;
  @override
  Future<void> restore(String userId) async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'token', userId: 'owner');
  });
  Future<void> real(WidgetTester tester, Future<void> Function() action) async {
    await tester.runAsync(() async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  Future<void> open(
      WidgetTester tester, _Commerce commerce, _Store store) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await real(
        tester,
        () => tester.pumpWidget(MaterialApp(
            home: PremiumPage(commerce: commerce, billing: store))));
  }

  test(
      'native history identity remains explicit through persistence, including legacy receipt compatibility',
      () {
    const transaction = StoreTransaction(
        'rc-history-id', 'zullo_superlikes_5', '2026-01-01T00:00:00Z');
    final history =
        RevenueCatBilling.historyReceipt(transaction, store: 'play_store');
    expect(history.identifierKind, 'revenuecat');
    expect(
        StorePurchase.fromJson(history.toJson()).identifierKind, 'revenuecat');
    expect(
        StorePurchase.fromJson({
          'store': 'app_store',
          'transactionId': 'store-id',
          'productId': 'zullo_boost_1'
        }).identifierKind,
        'store');
    expect(
        () => StorePurchase.fromJson({
              'store': 'app_store',
              'transactionId': 'x',
              'productId': 'zullo_boost_1',
              'identifierKind': 'unknown'
            }),
        throwsFormatException);
  });
  for (final relativeMinutes in [-2, 1]) {
    testWidgets(
        'receiptless checkout never infers confirmation from old or other-device history $relativeMinutes',
        (tester) async {
      final storage = PendingPurchaseStorage();
      final started =
          DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      await storage.save(
          'owner', PendingStorePurchase('zullo_superlikes_5', started));
      final commerce = _Commerce(), store = _Store();
      store.history = [
        StorePurchase('app_store', 'rc-other-attempt', 'zullo_superlikes_5',
            purchaseDate: started.add(Duration(minutes: relativeMinutes)),
            identifierKind: 'revenuecat')
      ];
      await open(tester, commerce, store);
      expect(store.buys, 0);
      expect(commerce.checks, 0);
      expect(await tester.runAsync(() => storage.read('owner')), isNotNull);
      expect(find.textContaining('dubbel debitering'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'known provider receipt persists and confirms after page restart without another purchase',
      (tester) async {
    final storage = PendingPurchaseStorage();
    await storage.save(
        'owner',
        PendingStorePurchase('zullo_superlikes_5', DateTime.now().toUtc(),
            receipt: const StorePurchase(
                'app_store', 'rc-known', 'zullo_superlikes_5',
                identifierKind: 'revenuecat')));
    final commerce = _Commerce(), store = _Store();
    await open(tester, commerce, store);
    expect(store.buys, 0);
    expect(commerce.lastReceipt?.identifierKind, 'revenuecat');
    expect(commerce.lastReceipt?.transactionId, 'rc-known');
    expect(await tester.runAsync(() => storage.read('owner')), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'checkout reservation is atomic across paywalls and scoped to the account',
      () async {
    final storage = PendingPurchaseStorage();
    final attempts = await Future.wait([
      for (var i = 0; i < 2; i++)
        storage
            .reserve('owner', 'zullo_boost_1')
            .then<Object>((value) => value)
            .catchError((Object failure) => failure)
    ]);
    expect(attempts.whereType<PendingStorePurchase>().length, 1);
    expect(attempts.whereType<PendingCheckoutException>().length, 1);
    expect(await storage.read('other'), isNull);
    expect(await storage.reserve('other', 'zullo_boost_1'),
        isA<PendingStorePurchase>());
  });
  test('old callbacks cannot attach or clear a newer checkout record',
      () async {
    final storage = PendingPurchaseStorage();
    final old = await storage.reserve('owner', 'zullo_boost_1');
    await storage.clear('owner', expected: old);
    final next = await storage.reserve('owner', 'zullo_boost_1');
    expect(
        await storage.attachReceipt('owner', old,
            const StorePurchase('app_store', 'old', 'zullo_boost_1')),
        isFalse);
    await storage.clear('owner', expected: old);
    expect((await storage.read('owner'))!.startedAt, next.startedAt);
  });
  testWidgets(
      'consumable confirmation uses exact verified receipt even if credits were already spent',
      (tester) async {
    final commerce = _Commerce(), store = _Store();
    await open(tester, commerce, store);
    await tester.ensureVisible(find.text('Köp'));
    await real(tester, () => tester.tap(find.text('Köp')));
    expect(store.buys, 1);
    expect(commerce.checks, greaterThanOrEqualTo(1));
    expect(await tester.runAsync(() => PendingPurchaseStorage().read('owner')),
        isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'unverified receipt stays blocked despite an unrelated balance increase',
      (tester) async {
    final storage = PendingPurchaseStorage();
    await storage.save(
        'owner',
        PendingStorePurchase('zullo_superlikes_5', DateTime.now().toUtc(),
            receipt: const StorePurchase(
                'app_store', 'unverified', 'zullo_superlikes_5')));
    final commerce = _Commerce()
      ..verified = false
      ..current = const CommerceState(checkoutEnabled: true, superLikes: 5);
    final store = _Store();
    await open(tester, commerce, store);
    await tester.ensureVisible(find.text('Uppdatera saldo'));
    await real(tester, () => tester.tap(find.text('Uppdatera saldo')));
    expect(commerce.checks, greaterThanOrEqualTo(1));
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Köp'))
            .onPressed,
        isNull);
    expect(store.buys, 0);
    expect(await tester.runAsync(() => storage.read('owner')), isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'unknown store outcome persists across page reopening and prevents another charge',
      (tester) async {
    final commerce = _Commerce(),
        store = _Store()..failure = StateError('interrupted');
    await open(tester, commerce, store);
    await tester.ensureVisible(find.text('Köp'));
    await real(tester, () => tester.tap(find.text('Köp')));
    expect(store.buys, 1);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Köp'))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox());
    await real(
        tester,
        () => tester.pumpWidget(MaterialApp(
            home: PremiumPage(commerce: commerce, billing: store))));
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Köp'))
            .onPressed,
        isNull);
    expect(await tester.runAsync(() => PendingPurchaseStorage().read('owner')),
        isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('definite store cancellation releases the checkout guard',
      (tester) async {
    final store = _Store()
      ..failure = PlatformException(code: '1', message: 'cancelled');
    await open(tester, _Commerce(), store);
    await tester.ensureVisible(find.text('Köp'));
    await real(tester, () => tester.tap(find.text('Köp')));
    expect(await tester.runAsync(() => PendingPurchaseStorage().read('owner')),
        isNull);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Köp'))
            .onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'one Premium has monthly and annual native prices without marketing a legacy privacy subscription',
      (tester) async {
    await open(tester, _Commerce(), _Store(plans: true));
    expect(find.text('Månadsvis'), findsOneWidget);
    expect(find.text('Årsvis'), findsOneWidget);
    expect(find.text('59,00 kr per månad'), findsOneWidget);
    expect(find.text('499,00 kr per år'), findsOneWidget);
    expect(find.text('Legacy privacy'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  test(
      'native catalog accepts explicit monthly or annual cadence and never guesses a period',
      () {
    expect(RevenueCatBilling.canonicalProduct('zullo_premium:monthly', 'P1M'),
        'zullo_premium_monthly');
    expect(RevenueCatBilling.canonicalProduct('zullo_premium:annual', 'P1Y'),
        'zullo_premium_annual');
    expect(RevenueCatBilling.canonicalProduct('zullo_premium', null), isNull);
    expect(RevenueCatBilling.canonicalProduct('zullo_premium_monthly', 'P1Y'),
        isNull);
  });
}
