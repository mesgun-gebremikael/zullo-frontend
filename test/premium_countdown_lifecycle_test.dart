import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/premium_page.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/commerce_service.dart';

class CountdownCommerce extends CommerceClient {
  CountdownCommerce(this.until);
  final DateTime until;
  @override
  Future<CommerceState> state() async => CommerceState(boostUntil: until);
}

class NoCountdownBilling extends NativeBilling {
  @override
  bool get available => false;
  @override
  Future<List<StoreOffer>> offers(String userId) async => [];
  @override
  Future<StorePurchase> buy(StoreOffer offer, String userId) =>
      throw UnimplementedError();
  @override
  Future<void> restore(String userId) async {}
}

void main() {
  testWidgets(
      'boost countdown pauses in background and stops repainting after expiry',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'test', userId: 'owner');
    var now = DateTime.utc(2026, 11, 27);
    final until = now.add(const Duration(seconds: 20));
    await tester.pumpWidget(MaterialApp(
        home: PremiumPage(
            commerce: CountdownCommerce(until),
            billing: NoCountdownBilling(),
            now: () => now)));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    Text title() => tester.widget<Text>(find.text('ZULLO Premium'));
    final runningTitle = title();
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(identical(title(), runningTitle), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final backgroundTitle = title();
    now = until.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 30));
    expect(identical(title(), backgroundTitle), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final expiredTitle = title();
    expect(identical(expiredTitle, backgroundTitle), isFalse);
    await tester.pump(const Duration(seconds: 30));
    expect(identical(title(), expiredTitle), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
