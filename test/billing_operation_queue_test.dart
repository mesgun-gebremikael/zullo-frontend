import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/billing_operation_queue.dart';
import 'package:zullo_app/services/pending_store_purchase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logout during store identity preparation cannot open payment sheet',
      () async {
    final queue = BillingOperationQueue();
    final preparing = Completer<void>(), prepared = Completer<void>();
    var charges = 0;
    final purchase = queue.run(() async => charges++, prepare: () async {
      preparing.complete();
      await prepared.future;
    });
    final rejected =
        expectLater(purchase, throwsA(isA<SessionChangedException>()));
    await preparing.future;
    AccountSession.reset();
    prepared.complete();
    await rejected;
    expect(charges, 0);

    // A rejected old operation must not poison the new account's queue.
    expect(await queue.run(() async => 'new account'), 'new account');
  });

  test('queued old account never prepares identity after account change',
      () async {
    final queue = BillingOperationQueue();
    final active = Completer<void>();
    final first = queue.run(() => active.future);
    final firstRejected =
        expectLater(first, throwsA(isA<SessionChangedException>()));
    var identityChanges = 0, charges = 0;
    final queued = queue.run(() async => charges++, prepare: () async {
      identityChanges++;
    });
    final queuedRejected =
        expectLater(queued, throwsA(isA<SessionChangedException>()));
    await Future<void>.delayed(Duration.zero);
    AccountSession.reset();
    active.complete();
    await Future.wait([firstRejected, queuedRejected]);
    expect(identityChanges, 0);
    expect(charges, 0);
  });

  test(
      'successful receipt survives logout only for original-account persistence',
      () async {
    final queue = BillingOperationQueue();
    final launched = Completer<void>();
    final nativeReceipt = Completer<StorePurchase>();
    final purchase = queue.run(() {
      launched.complete();
      return nativeReceipt.future;
    }, preserveResultOnSessionChange: true);
    await launched.future;
    AccountSession.reset();
    const receipt = StorePurchase('app_store', 'exact', 'zullo_boost_1');
    nativeReceipt.complete(receipt);
    expect(await purchase, same(receipt));
  });

  test('receipt preservation never allows an old queued checkout to start',
      () async {
    final queue = BillingOperationQueue();
    final active = Completer<void>();
    final blocker = queue.run(() => active.future);
    final rejectedBlocker =
        expectLater(blocker, throwsA(isA<SessionChangedException>()));
    var charges = 0;
    final oldPurchase =
        queue.run(() async => charges++, preserveResultOnSessionChange: true);
    final rejectedPurchase =
        expectLater(oldPurchase, throwsA(isA<SessionChangedException>()));
    await Future<void>.delayed(Duration.zero);
    AccountSession.reset();
    active.complete();
    await Future.wait([rejectedBlocker, rejectedPurchase]);
    expect(charges, 0);
  });

  test('identity and payment remain serialized for one account', () async {
    final queue = BillingOperationQueue();
    final firstPrepared = Completer<void>(), releaseFirst = Completer<void>();
    final events = <String>[];
    final first = queue.run(() async {
      events.add('purchase A');
      await releaseFirst.future;
    }, prepare: () async {
      events.add('identity A');
      firstPrepared.complete();
    });
    await firstPrepared.future;
    final second = queue.run(() async => events.add('purchase B'),
        prepare: () async => events.add('identity B'));
    await Future<void>.delayed(Duration.zero);
    expect(events, ['identity A', 'purchase A']);
    releaseFirst.complete();
    await first;
    await second;
    expect(events, ['identity A', 'purchase A', 'identity B', 'purchase B']);
  });
}
