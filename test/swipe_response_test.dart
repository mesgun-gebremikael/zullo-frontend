import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/home_page.dart';
import 'package:zullo_app/models/swipe_profile.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/widgets/swipe_profile_card.dart';

class DelayedSwipeAuth extends AuthService {
  final response = Completer<bool>();
  int likes = 0;
  Completer<Map<String, dynamic>>? pendingFeed;
  @override
  Future<Map<String, dynamic>> getSwipeFeed(
      {int minAge = 18, int maxAge = 99}) async {
    if (pendingFeed != null) return pendingFeed!.future;
    return {
      'profiles': List.generate(
          4,
          (i) => SwipeProfile.fromJson({
                'userId': 'peer-$i',
                'displayName': 'Person $i',
                'age': 28,
                'photoUrls': <String>[]
              })),
      'radiusKm': 50.0
    };
  }

  @override
  Future<Map<String, dynamic>> getMyProfile() async =>
      {'photoUrls': <String>[]};
  @override
  Future<List<dynamic>> getMatches() async => [];
  @override
  Future<bool> like(String targetUserId, {bool superLike = false}) {
    likes++;
    return response.future;
  }
}

Finder card(String id) => find
    .byWidgetPredicate((w) => w is SwipeProfileCard && w.profile.userId == id);
void main() {
  testWidgets(
      'swipe animates before network completes and serializes rapid taps',
      (tester) async {
    final auth = DelayedSwipeAuth();
    await tester.pumpWidget(MaterialApp(home: HomePage(authService: auth)));
    await tester.pumpAndSettle();
    final start = tester.getTopLeft(card('peer-0'));
    await tester.tap(find.byTooltip('Gilla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(card('peer-0')).dx, greaterThan(start.dx + 20));
    await tester.tap(find.byTooltip('Gilla'));
    expect(auth.likes, 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(card('peer-0'), findsOneWidget); // No accepted action yet.
    auth.response.complete(false);
    await tester.pumpAndSettle();
    expect(card('peer-0'), findsNothing);
    expect(card('peer-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'a feed response cannot replace a profile during an accepted swipe',
      (tester) async {
    final auth = DelayedSwipeAuth();
    await tester.pumpWidget(MaterialApp(home: HomePage(authService: auth)));
    await tester.pumpAndSettle();
    auth.pendingFeed = Completer<Map<String, dynamic>>();
    final dynamic state = tester.state(find.byType(HomePage));
    final Future<void> refresh = state.loadFeed(background: true);
    await tester.pump();
    await tester.tap(find.byTooltip('Gilla'));
    await tester.pump(const Duration(milliseconds: 250));
    auth.pendingFeed!.complete({
      'profiles': [
        SwipeProfile.fromJson({
          'userId': 'fresh',
          'displayName': 'Fresh person',
          'age': 30,
          'photoUrls': <String>[]
        })
      ],
      'radiusKm': 50.0
    });
    await refresh;
    await tester.pump();
    expect(card('peer-0'), findsOneWidget);
    expect(card('fresh'), findsNothing);
    auth.response.complete(false);
    await tester.pumpAndSettle();
    expect(card('fresh'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('canceling a drag restores the card without submitting a swipe',
      (tester) async {
    final auth = DelayedSwipeAuth();
    await tester.pumpWidget(MaterialApp(home: HomePage(authService: auth)));
    await tester.pumpAndSettle();
    final start = tester.getTopLeft(card('peer-0'));
    final gesture = await tester.startGesture(tester.getCenter(card('peer-0')));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card('peer-0')), start);
    expect(auth.likes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('a failed swipe retains the profile and allows retry',
      (tester) async {
    final auth = DelayedSwipeAuth();
    await tester.pumpWidget(MaterialApp(home: HomePage(authService: auth)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Gilla'));
    await tester.pump(const Duration(milliseconds: 250));
    auth.response.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(card('peer-0'), findsOneWidget);
    expect(tester.getTopLeft(card('peer-0')).dx, closeTo(8, 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('disposing during swipe does not update a disposed controller',
      (tester) async {
    final auth = DelayedSwipeAuth();
    await tester.pumpWidget(MaterialApp(home: HomePage(authService: auth)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Gilla'));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(const SizedBox());
    auth.response.complete(false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
