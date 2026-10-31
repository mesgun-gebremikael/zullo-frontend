import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/home_page.dart';
import 'package:zullo_app/models/swipe_profile.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/account_session.dart';

class FeedAuth extends AuthService {
  int calls = 0;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> getSwipeFeed({int minAge = 18, int maxAge = 99}) {
    calls++;
    return pending?.future ?? Future.value({'profiles': <SwipeProfile>[], 'radiusKm': 50.0});
  }
  @override
  Future<Map<String, dynamic>> getMyProfile() async => {'photoUrls': [], 'intention': 'Relationship', 'religion': 'Private'};
  @override
  Future<List<dynamic>> getMatches() async => [];
}

void main() {
  testWidgets('empty discovery refreshes without overlap and stops offscreen and after logout', (tester) async {
    final auth = FeedAuth();
    Widget page(bool active) => MaterialApp(home: HomePage(active: active, authService: auth));
    await tester.pumpWidget(page(true));
    await tester.pump();
    final initial = auth.calls; // Includes the existing prefetch.
    expect(initial, greaterThan(0));
    auth.pending = Completer<Map<String, dynamic>>();
    await tester.pump(const Duration(seconds: 20));
    expect(auth.calls, initial + 1);
    await tester.pump(const Duration(seconds: 40));
    expect(auth.calls, initial + 1);
    auth.pending!.complete({'profiles': <SwipeProfile>[], 'radiusKm': 50.0});
    auth.pending = null;
    await tester.pump();
    await tester.pumpWidget(page(false));
    final hiddenCalls = auth.calls;
    await tester.pump(const Duration(seconds: 40));
    expect(auth.calls, hiddenCalls);
    await tester.pumpWidget(page(true));
    await tester.pump();
    expect(auth.calls, greaterThan(hiddenCalls));
    AccountSession.reset();
    final loggedOutCalls = auth.calls;
    await tester.pump(const Duration(seconds: 40));
    expect(auth.calls, loggedOutCalls);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 40));
    expect(auth.calls, loggedOutCalls);
    expect(tester.takeException(), isNull);
  });
}
