import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/premium_page.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/commerce_service.dart';
import 'package:zullo_app/services/pending_store_purchase.dart';

const _receipt =
    StorePurchase('app_store', 'exact-owned-receipt', 'zullo_superlikes_5');

class _RecoveryCommerce extends CommerceClient {
  int syncs = 0, checks = 0, stateReads = 0;
  VoidCallback? onProof;
  bool verified = true, refunded = false;
  Object? failure;
  Completer<CommerceState>? pendingSync;
  CommerceState current = const CommerceState(superLikes: 1);
  final synchronized = const CommerceState(superLikes: 6);
  @override
  Future<CommerceState> state() async {
    stateReads++;
    return current;
  }

  @override
  Future<CommerceState> sync() async {
    syncs++;
    if (failure != null) throw failure!;
    final fresh = await (pendingSync?.future ?? Future.value(synchronized));
    current = fresh;
    return fresh;
  }

  @override
  Future<({bool verified, bool refunded})> purchaseStatus(
      StorePurchase receipt) async {
    checks++;
    expect(syncs, greaterThan(0));
    expect(receipt.transactionId, _receipt.transactionId);
    expect(receipt.productId, _receipt.productId);
    onProof?.call();
    return (verified: verified, refunded: refunded);
  }
}

class _NoAutomaticPurchase extends NativeBilling {
  int purchases = 0, restores = 0;
  @override
  bool get available => false;
  @override
  Future<List<StoreOffer>> offers(String userId) async => [];
  @override
  Future<StorePurchase> buy(StoreOffer offer, String userId) async {
    purchases++;
    throw StateError('Recovery must never start another purchase');
  }

  @override
  Future<void> restore(String userId) async {
    restores++;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'owner-token', userId: 'owner');
  });

  Future<PendingStorePurchase> record({bool withReceipt = true}) async {
    final storage = PendingPurchaseStorage();
    final pending = await storage.reserve('owner', _receipt.productId);
    if (withReceipt) {
      await storage.attachReceipt('owner', pending, _receipt);
    }
    return pending;
  }

  Future<void> drain(WidgetTester tester) async {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }

  Future<void> open(WidgetTester tester, _RecoveryCommerce commerce,
      _NoAutomaticPurchase billing) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await tester.pumpWidget(
          MaterialApp(home: PremiumPage(commerce: commerce, billing: billing)));
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pump();
  }

  testWidgets(
      'opening a saved exact receipt synchronizes and verifies it without another purchase',
      (tester) async {
    await tester.runAsync(() => record());
    final commerce = _RecoveryCommerce(), billing = _NoAutomaticPurchase();
    await open(tester, commerce, billing);
    await drain(tester);
    expect(commerce.syncs, 1);
    expect(commerce.checks, 1);
    expect(await tester.runAsync(() => PendingPurchaseStorage().read('owner')),
        isNull);
    expect(find.text('6'), findsOneWidget);
    expect(billing.purchases, 0);
    expect(billing.restores, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'receiptless checkout is retained without automatic synchronization',
      (tester) async {
    await tester.runAsync(() => record(withReceipt: false));
    final commerce = _RecoveryCommerce(), billing = _NoAutomaticPurchase();
    await open(tester, commerce, billing);
    expect(commerce.syncs, 0);
    expect(commerce.checks, 0);
    expect(await tester.runAsync(() => PendingPurchaseStorage().read('owner')),
        isNotNull);
    expect(billing.purchases, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'failed synchronization retains known receipt and verified balance',
      (tester) async {
    await tester.runAsync(() => record());
    final commerce = _RecoveryCommerce()
      ..failure = StateError('offline')
      ..verified = false;
    final billing = _NoAutomaticPurchase();
    await open(tester, commerce, billing);
    expect(commerce.syncs, 1);
    expect(commerce.checks, 1);
    expect(
        (await tester.runAsync(() => PendingPurchaseStorage().read('owner')))
            ?.receipt
            ?.transactionId,
        _receipt.transactionId);
    expect(find.text('1'), findsOneWidget);
    expect(billing.purchases, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final refunded in [false, true]) {
    testWidgets('provider outage accepts exact ledger proof refunded=$refunded',
        (tester) async {
      await tester.runAsync(() => record());
      final commerce = _RecoveryCommerce()
        ..failure = StateError('provider offline')
        ..verified = !refunded
        ..refunded = refunded;
      final billing = _NoAutomaticPurchase();
      await open(tester, commerce, billing);
      expect(commerce.syncs, 1);
      expect(commerce.checks, 1);
      expect(
          await tester.runAsync(() => PendingPurchaseStorage().read('owner')),
          isNull);
      // Keep the last server-verified balance rather than fabricate a new grant.
      expect(find.text('1'), findsOneWidget);
      expect(billing.purchases, 0);
      expect(billing.restores, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'verified recovery refreshes a wallet committed after its first snapshot',
      (tester) async {
    await tester.runAsync(() => record());
    final commerce = _RecoveryCommerce()
      ..failure = StateError('provider offline');
    commerce.onProof = () => commerce.current = commerce.synchronized;
    final billing = _NoAutomaticPurchase();
    await open(tester, commerce, billing);
    await drain(tester);
    expect(commerce.stateReads, 2);
    expect(find.text('6'), findsOneWidget);
    expect(await tester.runAsync(() => PendingPurchaseStorage().read('owner')),
        isNull);
    expect(billing.purchases, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'foreground retries coalesce and clear only a verified exact receipt',
      (tester) async {
    await tester.runAsync(() => record());
    final commerce = _RecoveryCommerce()..verified = false;
    final billing = _NoAutomaticPurchase();
    await open(tester, commerce, billing);
    expect(commerce.syncs, 1);
    expect(await tester.runAsync(() => PendingPurchaseStorage().read('owner')),
        isNotNull);
    commerce.pendingSync = Completer<CommerceState>();
    await tester.runAsync(() async {
      for (var i = 0; i < 3; i++) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    expect(commerce.syncs, 2);
    await tester.runAsync(() async {
      commerce.verified = true;
      commerce.pendingSync!.complete(commerce.synchronized);
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    expect(commerce.checks, 2);
    expect(await tester.runAsync(() => PendingPurchaseStorage().read('owner')),
        isNull);
    expect(billing.purchases, 0);
    expect(billing.restores, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('account change during recovery never clears the original guard',
      (tester) async {
    await tester.runAsync(() => record());
    final commerce = _RecoveryCommerce()
      ..pendingSync = Completer<CommerceState>();
    final billing = _NoAutomaticPurchase();
    await open(tester, commerce, billing);
    expect(commerce.syncs, 1);
    await tester.runAsync(() async {
      AccountSession.reset();
      commerce.pendingSync!.complete(commerce.synchronized);
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    expect(commerce.checks, 0);
    expect(await tester.runAsync(() => PendingPurchaseStorage().read('owner')),
        isNotNull);
    expect(billing.purchases, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
