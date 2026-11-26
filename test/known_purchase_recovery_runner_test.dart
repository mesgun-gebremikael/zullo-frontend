import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/main_navigation.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/commerce_service.dart';
import 'package:zullo_app/services/known_purchase_recovery.dart';
import 'package:zullo_app/services/pending_store_purchase.dart';
import 'package:zullo_app/services/signalr_service.dart';

const _receipt =
    StorePurchase('app_store', 'known-owned-receipt', 'zullo_superlikes_5');

class _AuthStorage extends AuthStorage {
  int reads = 0;
  String? owner = 'owner';
  Completer<String?>? pending;
  @override
  Future<String?> getUserId() {
    reads++;
    return pending?.future ?? Future.value(owner);
  }
}

class _Pending extends PendingPurchaseStorage {
  int reads = 0, clears = 0, reservations = 0;
  Completer<PendingStorePurchase?>? delayed;
  PendingStorePurchase? value = PendingStorePurchase(
      _receipt.productId, DateTime.utc(2026),
      receipt: _receipt);
  @override
  Future<PendingStorePurchase?> read(String user) {
    expect(user, 'owner');
    reads++;
    return delayed?.future ?? Future.value(value);
  }

  @override
  Future<void> clear(String user, {PendingStorePurchase? expected}) async {
    clears++;
    throw StateError('Global synchronization must not clear purchase guards');
  }

  @override
  Future<PendingStorePurchase> reserve(String user, String product) async {
    reservations++;
    throw StateError('Recovery must not reserve another checkout');
  }
}

class _Commerce extends CommerceClient {
  int syncs = 0;
  Object? failure;
  Completer<CommerceState>? pending;
  @override
  Future<CommerceState> sync() async {
    syncs++;
    if (failure != null) throw failure!;
    return pending?.future ?? const CommerceState(superLikes: 5);
  }
}

class _Events {
  int wallets = 0, discovery = 0;
  _Events() {
    final wallet = CommerceEvents.walletStream.listen((_) => wallets++);
    final feed = CommerceEvents.stream.listen((_) => discovery++);
    addTearDown(wallet.cancel);
    addTearDown(feed.cancel);
  }
  Future<void> flush() => Future<void>.delayed(Duration.zero);
}

class _InjectedRecovery extends KnownPurchaseRecovery {
  int calls = 0;
  bool disposed = false;
  final pending = Completer<void>();
  @override
  Future<void> retry() {
    calls++;
    return pending.future;
  }

  @override
  void dispose() => disposed = true;
}

class _NavigationAuth extends AuthService {
  @override
  Future<List<dynamic>> getMatches() async => [];
  @override
  Future<void> syncPushToken() async {}
}

class _Live extends SignalRService {
  @override
  Future<void> connect() async {}
}

void main() {
  setUp(AccountSession.reset);

  for (final hasRecord in [false, true]) {
    test('startup skips missing/receiptless records hasRecord=$hasRecord',
        () async {
      final auth = _AuthStorage();
      final pending = _Pending()
        ..value = hasRecord
            ? PendingStorePurchase(_receipt.productId, DateTime.utc(2026))
            : null;
      final commerce = _Commerce();
      final events = _Events();
      final recovery = KnownPurchaseRecovery(
          authStorage: auth, purchaseStorage: pending, commerce: commerce);
      await recovery.retry();
      await events.flush();
      expect(commerce.syncs, 0);
      expect(pending.clears, 0);
      expect(pending.reservations, 0);
      expect(events.wallets, 0);
      expect(events.discovery, 0);
      recovery.dispose();
    });
  }

  test('known receipt sync refreshes wallet/feed without clearing or buying',
      () async {
    final auth = _AuthStorage(), pending = _Pending();
    final commerce = _Commerce();
    final events = _Events();
    final recovery = KnownPurchaseRecovery(
        authStorage: auth, purchaseStorage: pending, commerce: commerce);
    await recovery.retry();
    await events.flush();
    expect(commerce.syncs, 1);
    expect(events.wallets, 1);
    expect(events.discovery, 1);
    expect(pending.value?.receipt, same(_receipt));
    expect(pending.clears, 0);
    expect(pending.reservations, 0);
    recovery.dispose();
  });

  test('overlapping foreground retries share the same recovery operation',
      () async {
    final commerce = _Commerce()..pending = Completer<CommerceState>();
    final recovery = KnownPurchaseRecovery(
        authStorage: _AuthStorage(),
        purchaseStorage: _Pending(),
        commerce: commerce);
    final first = recovery.retry(), second = recovery.retry();
    expect(second, same(first));
    await Future<void>.delayed(Duration.zero);
    expect(commerce.syncs, 1);
    commerce.pending!.complete(const CommerceState());
    await first;
    recovery.dispose();
  });

  test('provider failure stays silent and can retry on a later foreground',
      () async {
    final commerce = _Commerce()..failure = StateError('offline');
    final pending = _Pending();
    final events = _Events();
    final recovery = KnownPurchaseRecovery(
        authStorage: _AuthStorage(),
        purchaseStorage: pending,
        commerce: commerce);
    await recovery.retry();
    await events.flush();
    expect(events.wallets, 0);
    expect(pending.value?.receipt, isNotNull);
    commerce.failure = null;
    await recovery.retry();
    await events.flush();
    expect(commerce.syncs, 2);
    expect(events.wallets, 1);
    expect(events.discovery, 1);
    expect(pending.clears, 0);
    recovery.dispose();
  });

  test('account change while reading identity never synchronizes another owner',
      () async {
    final auth = _AuthStorage()..pending = Completer<String?>();
    final pending = _Pending();
    final commerce = _Commerce();
    final recovery = KnownPurchaseRecovery(
        authStorage: auth, purchaseStorage: pending, commerce: commerce);
    final result = recovery.retry();
    AccountSession.reset();
    auth.pending!.complete('owner');
    await result;
    expect(pending.reads, 0);
    expect(commerce.syncs, 0);
    recovery.dispose();
  });

  test('account change while reading the guard stops before provider sync',
      () async {
    final pending = _Pending()..delayed = Completer<PendingStorePurchase?>();
    final commerce = _Commerce();
    final recovery = KnownPurchaseRecovery(
        authStorage: _AuthStorage(),
        purchaseStorage: pending,
        commerce: commerce);
    final result = recovery.retry();
    await Future<void>.delayed(Duration.zero);
    AccountSession.reset();
    pending.delayed!.complete(pending.value);
    await result;
    expect(commerce.syncs, 0);
    recovery.dispose();
  });

  for (final dispose in [false, true]) {
    test('late recovery never refreshes stale UI dispose=$dispose', () async {
      final commerce = _Commerce()..pending = Completer<CommerceState>();
      final events = _Events();
      final recovery = KnownPurchaseRecovery(
          authStorage: _AuthStorage(),
          purchaseStorage: _Pending(),
          commerce: commerce);
      final result = recovery.retry();
      await Future<void>.delayed(Duration.zero);
      if (dispose) {
        recovery.dispose();
      } else {
        AccountSession.reset();
      }
      commerce.pending!.complete(const CommerceState(superLikes: 5));
      await result;
      await events.flush();
      expect(events.wallets, 0);
      expect(events.discovery, 0);
      await recovery.retry();
      expect(commerce.syncs, 1);
      recovery.dispose();
    });
  }

  test('inactive foreground guard skips even secure identity reads', () async {
    final auth = _AuthStorage();
    final recovery =
        KnownPurchaseRecovery(authStorage: auth, isActive: () => false);
    await recovery.retry();
    expect(auth.reads, 0);
    recovery.dispose();
  });

  testWidgets('navigation starts recovery without blocking retained tabs',
      (tester) async {
    final recovery = _InjectedRecovery();
    await tester.pumpWidget(MaterialApp(
        home: MainNavigation(
      authService: _NavigationAuth(),
      liveService: _Live(),
      purchaseRecovery: recovery,
      pages: const [
        Text('swipe-panel'),
        Text('likes-panel'),
        Text('chat-panel'),
        Text('profile-panel')
      ],
    )));
    await tester.pump();
    expect(find.text('swipe-panel'), findsOneWidget);
    expect(recovery.calls, 1);
    await tester.tap(find.text('Chattar'));
    await tester.pumpAndSettle();
    expect(find.text('chat-panel'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(recovery.calls, 2);
    await tester.pumpWidget(const SizedBox());
    expect(recovery.disposed, isTrue);
    recovery.pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
