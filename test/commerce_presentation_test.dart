import 'package:zullo_app/likes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/matches_page.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/widgets/commerce_cards.dart';
import 'package:zullo_app/widgets/discovery_empty_state.dart';

void main() {
  testWidgets('profile cards fit a narrow screen with enlarged text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
      child: Scaffold(
          body: SingleChildScrollView(
              child: Column(children: [
        ProfilePurchaseCard(
            icon: Icons.star_rounded,
            color: Colors.blue,
            title: '12 Superlikes',
            subtitle: 'FÅ MER',
            onTap: () {}),
        PremiumBenefitsCard(active: false, onTap: () {}),
      ]))),
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('Toppval'), findsNothing);
    expect(find.text('Dölj aktivitetsstatus'), findsOneWidget);
    expect(find.byType(ZulloMark), findsOneWidget);
  });

  testWidgets(
      'empty likes offers Premium while paid empty likes offers discovery',
      (tester) async {
    var taps = 0;
    for (final premium in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: DiscoveryEmptyState(
                  likes: true, premium: premium, onAction: () => taps++))));
      final button = find.widgetWithText(
          FilledButton, premium ? 'Börja swipa' : 'Se vem som gillar dig');
      await tester.tap(button);
      expect(tester.takeException(), isNull);
    }
    expect(taps, 2);
  });

  testWidgets(
      'Likes and Chats show distinct empty screens without fake likes or Top Picks',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().saveAuth(token: 'presentation', userId: 'presentation');
    final auth = AuthService(
        client: MockClient((request) async => http.Response(
            request.url.path.endsWith('/summary')
                ? '{"totalCount":0,"hiddenCount":0,"canViewAll":false}'
                : '[]',
            200)));
    for (final showLikes in [true, false]) {
      await tester.pumpWidget(MaterialApp(
          home: showLikes
              ? LikesPage(key: ValueKey(showLikes), authService: auth)
              : MatchesPage(key: ValueKey(showLikes), authService: auth)));
      await tester.pumpAndSettle();
      expect(find.text(showLikes ? 'Likes' : 'Chattar'), findsOneWidget);
      expect(find.text('Toppval'), findsNothing);
      expect(find.text('New Matches'), findsNothing);
      expect(find.text(showLikes ? 'Börja swipa' : 'Se vem som gillar dig'),
          findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
