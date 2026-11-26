import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/services/pending_store_purchase.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'same product and identical device time still identify different attempts',
      () async {
    final clock = DateTime.utc(2026, 11, 26);
    final storage = PendingPurchaseStorage(now: () => clock);
    final first = await storage.reserve('owner', 'zullo_boost_1');
    await storage.clear('owner', expected: first);
    final second = await storage.reserve('owner', 'zullo_boost_1');
    expect(first.startedAt, second.startedAt);
    expect(first.attemptId, isNotNull);
    expect(first.attemptId, isNot(second.attemptId));
    expect(
        await storage.attachReceipt('owner', first,
            const StorePurchase('app_store', 'old-receipt', 'zullo_boost_1')),
        isFalse);
    await storage.clear('owner', expected: first);
    expect((await storage.read('owner'))?.attemptId, second.attemptId);
    expect(
        await storage.attachReceipt(
            'owner',
            second,
            const StorePurchase(
                'app_store', 'current-receipt', 'zullo_boost_1')),
        isTrue);
    final saved = await storage.read('owner');
    expect(saved?.attemptId, second.attemptId);
    expect(saved?.receipt?.transactionId, 'current-receipt');
  });
  test(
      'legacy guards survive and old callbacks cannot clear a new same-time attempt',
      () async {
    final started = DateTime.utc(2026, 11, 26);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        'zullo.pending_purchase.v1.owner',
        jsonEncode({
          'productId': 'zullo_boost_1',
          'startedAt': started.toIso8601String(),
          'receipt': {
            'store': 'play_store',
            'transactionId': 'old',
            'productId': 'zullo_boost_1'
          }
        }));
    final storage = PendingPurchaseStorage(now: () => started);
    final old = (await storage.read('owner'))!;
    expect(old.attemptId, isNull);
    expect(old.receipt?.transactionId, 'old');
    await expectLater(storage.reserve('owner', old.productId),
        throwsA(isA<PendingCheckoutException>()));
    await storage.clear('owner', expected: old);
    final current = await storage.reserve('owner', old.productId);
    await storage.clear('owner', expected: old);
    expect((await storage.read('owner'))?.attemptId, current.attemptId);
  });
  test(
      'damaged attempt identity fails closed instead of allowing another charge',
      () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        'zullo.pending_purchase.v1.owner',
        jsonEncode({
          'productId': 'zullo_boost_1',
          'startedAt': DateTime.utc(2026).toIso8601String(),
          'attemptId': ''
        }));
    final storage = PendingPurchaseStorage();
    await expectLater(storage.read('owner'), throwsFormatException);
    await expectLater(
        storage.reserve('owner', 'zullo_boost_1'), throwsFormatException);
    expect(preferences.containsKey('zullo.pending_purchase.v1.owner'), isTrue);
  });
}
