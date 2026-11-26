import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/premium_page.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/commerce_service.dart';

class _Commerce extends CommerceClient {
  int loads = 0;
  Completer<CommerceState>? delayed;
  CommerceState current = const CommerceState(checkoutEnabled: true);
  @override
  Future<CommerceState> state() {
    loads++;
    return delayed?.future ?? Future.value(current);
  }

  @override
  Future<CommerceState> sync() async => current;
  @override
  Future<({bool verified, bool refunded})> purchaseStatus(
          StorePurchase receipt) async =>
      (verified: true, refunded: false);
}

class _Store extends NativeBilling {
  int loads = 0, purchases = 0;
  Completer<List<StoreOffer>>? pendingOffers;
  Completer<StorePurchase>? pendingPurchase;
  static const offer =
      StoreOffer('zullo_superlikes_5', '5 Superlikes', '€2.99', 1);
  @override
  bool get available => true;
  @override
  Future<List<StoreOffer>> offers(String userId) {
    loads++;
    return pendingOffers?.future ?? Future.value([offer]);
  }

  @override
  Future<StorePurchase> buy(StoreOffer offer, String userId) {
    purchases++;
    return pendingPurchase!.future;
  }

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
  Future<void> drain(WidgetTester tester) async {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }

  Future<void> open(
      WidgetTester tester, _Commerce commerce, _Store store) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await tester.pumpWidget(
          MaterialApp(home: PremiumPage(commerce: commerce, billing: store)));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
  }

  testWidgets(
      'loading store prices never flashes unavailable and refreshes coalesce',
      (tester) async {
    final commerce = _Commerce(), store = _Store()..pendingOffers = Completer();
    await open(tester, commerce, store);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Köp är inte tillgängliga'), findsNothing);
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    final first = refresh(), second = refresh();
    await drain(tester);
    expect(commerce.loads, 1);
    expect(store.loads, 1);
    store.pendingOffers!.complete([_Store.offer]);
    await Future.wait([first, second]);
    await drain(tester);
    expect(find.text('€2.99'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Köp'))
            .onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'payment gives feedback inside tapped button and cannot double submit or refresh',
      (tester) async {
    final commerce = _Commerce(),
        store = _Store()..pendingPurchase = Completer();
    await open(tester, commerce, store);
    final purchaseButton = find.widgetWithText(FilledButton, 'Köp');
    await tester.ensureVisible(purchaseButton);
    await tester.runAsync(() async {
      await tester.tap(purchaseButton);
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    expect(store.purchases, 1);
    final progress = find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator));
    expect(progress, findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.ancestor(of: progress, matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    expect(commerce.loads, 1);
    store.pendingPurchase!.complete(const StorePurchase(
        'app_store', 'owned-transaction', 'zullo_superlikes_5'));
    await drain(tester);
    await drain(tester);
    expect(store.purchases, 1);
    expect(find.widgetWithText(FilledButton, 'Köp'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'wallet event burst coalesces and rechecks latest balance after in-flight response',
      (tester) async {
    final commerce = _Commerce(), store = _Store();
    await open(tester, commerce, store);
    final delayed = Completer<CommerceState>();
    commerce.delayed = delayed;
    CommerceEvents.walletChanged();
    await drain(tester);
    CommerceEvents.walletChanged();
    CommerceEvents.walletChanged();
    await drain(tester);
    expect(commerce.loads, 2);
    commerce.delayed = null;
    commerce.current =
        const CommerceState(checkoutEnabled: true, superLikes: 7);
    delayed.complete(const CommerceState(checkoutEnabled: true));
    await drain(tester);
    await drain(tester);
    expect(commerce.loads, 3);
    expect(find.text('7'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'late pre-purchase wallet response cannot replace confirmed balance',
      (tester) async {
    final commerce = _Commerce(),
        store = _Store()..pendingPurchase = Completer();
    await open(tester, commerce, store);
    final stale = Completer<CommerceState>();
    commerce.delayed = stale;
    CommerceEvents.walletChanged();
    await drain(tester);
    commerce.delayed = null;
    commerce.current =
        const CommerceState(checkoutEnabled: true, superLikes: 5);
    await tester.ensureVisible(find.text('Köp'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Köp'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    store.pendingPurchase!.complete(const StorePurchase(
        'app_store', 'owned-transaction', 'zullo_superlikes_5'));
    await drain(tester);
    await drain(tester);
    expect(find.text('5'), findsOneWidget);
    stale.complete(const CommerceState(checkoutEnabled: true));
    await drain(tester);
    expect(find.text('5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
