import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/main_navigation.dart';
import 'package:zullo_app/models/swipe_profile.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/signalr_service.dart';
import 'package:zullo_app/swipe_page.dart';
import 'package:zullo_app/widgets/swipe_profile_card.dart';
import 'support/fake_chat_transport.dart';

class _Auth extends AuthService {
  @override
  Future<List<dynamic>> getMatches() async => [];
}

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets(
          'active swipe name, details, actions and navigation stay separate $width/$scale',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final drag = ValueNotifier(Offset.zero);
        addTearDown(drag.dispose);
        final p = SwipeProfile.fromJson({
          'userId': 'spacing-test',
          'displayName': 'A very long profile name',
          'age': 24,
          'livePlace': 'Stockholm',
          'distanceKm': 5
        });
        final page = LayoutBuilder(
            builder: (context, constraints) => SwipePage(
                  isLoading: false,
                  hasActiveProfile: true,
                  hasUnreadMessages: false,
                  dragListenable: drag,
                  nextCard: null,
                  activeCard: LayoutBuilder(
                      builder: (context, card) => SwipeProfileCard(
                          profile: p,
                          width: card.maxWidth,
                          height: card.maxHeight)),
                  emptyState: const SizedBox(),
                  onOpenRadiusSheet: () {},
                  onOpenMatchesPage: () {},
                  onSwipeLeft: () {},
                  onSwipeUp: () {},
                  onSwipeRight: () {},
                  onRewind: () {},
                ));
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MainNavigation(
              authService: _Auth(),
              liveService: SignalRService(transport: FakeChatTransport()),
              pages: [
                page,
                const SizedBox(),
                const SizedBox(),
                const SizedBox()
              ]),
        )));
        await tester.pumpAndSettle();
        final name = tester.getRect(find.text('A very long profile name'));
        final age = tester.getRect(find.text('24'));
        final details = tester.getRect(find.byTooltip('Läs hela profilen'));
        final dismiss = tester.getRect(find.byTooltip('Hoppa över'));
        final like = tester.getRect(find.byTooltip('Gilla'));
        final rewind = tester.getRect(find.byTooltip('Ångra senaste swipe'));
        final nav = tester.getRect(find.text('Swipa'));
        expect(name.right, lessThan(age.left));
        expect(age.right, lessThan(details.left));
        expect(name.bottom, lessThan(dismiss.top));
        expect(details.bottom, lessThan(dismiss.top));
        expect(dismiss.bottom, lessThan(nav.top));
        expect(like.bottom, lessThan(nav.top));
        expect(rewind.right, lessThan(dismiss.left));
        expect(find.text('ZULLO'), findsNothing);
        expect(find.byIcon(Icons.edit), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
