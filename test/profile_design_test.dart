import 'package:zullo_app/theme/zullo_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/edit_profile_page.dart';
import 'package:zullo_app/main_navigation.dart';
import 'package:zullo_app/services/signalr_service.dart';
import 'package:zullo_app/swipe_page.dart';
import 'support/fake_chat_transport.dart';
import 'package:zullo_app/profile_page.dart';
import 'package:zullo_app/models/swipe_profile.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/widgets/discovery_feed_empty.dart';
import 'package:zullo_app/widgets/profile_basics_section.dart';
import 'package:zullo_app/widgets/profile_story.dart';
import 'package:zullo_app/widgets/swipe_profile_card.dart';

class PreviewAuth extends AuthService {
  @override
  Future<List<dynamic>> getMatches() async => [];
  @override
  Future<Map<String, dynamic>> getMyProfile() async => {
        'displayName': 'Nora',
        'age': 28,
        'gender': 'Kvinna',
        'photoUrls': <String>[],
        'bio': 'Den gamla presentationen',
        'religion': 'Kristen',
      };
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['ZULLO_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (Platform.environment['ZULLO_CAPTURE_DIR'] != null) {
      final loader = FontLoader('Roboto')
        ..addFont(File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)));
      await loader.load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    }
  });
  for (final scale in [1.0, 1.8]) {
    testWidgets('empty discovery fits compact screen at text scale $scale',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      var actions = 0;
      await tester.pumpWidget(MaterialApp(
          theme: zulloTheme(),
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                  key: key,
                  child: Scaffold(
                      backgroundColor: const Color(0xFFFFF8F5),
                      body: DiscoveryFeedEmpty(
                          paused: false, onAction: () => actions++))))));
      await tester.ensureVisible(find.text('Ändra filter'));
      await tester.tap(find.text('Ändra filter'));
      expect(actions, 1);
      expect(tester.takeException(), isNull);
      if (scale == 1) await capture(tester, key, 'discovery');
    });
  }
  for (final scale in [1.0, 1.8]) {
    testWidgets('navigation remains below content with large text $scale',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      final drag = ValueNotifier(Offset.zero);
      addTearDown(drag.dispose);
      final empty = SwipePage(
          isLoading: false,
          hasActiveProfile: false,
          hasUnreadMessages: false,
          dragListenable: drag,
          nextCard: null,
          activeCard: const SizedBox(),
          emptyState: DiscoveryFeedEmpty(paused: false, onAction: () {}),
          onOpenRadiusSheet: () {},
          onOpenMatchesPage: () {},
          onSwipeLeft: () {},
          onSwipeUp: () {},
          onSwipeRight: () {});
      await tester.pumpWidget(MaterialApp(
          theme: zulloTheme(),
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                  key: key,
                  child: MainNavigation(
                      authService: PreviewAuth(),
                      liveService:
                          SignalRService(transport: FakeChatTransport()),
                      pages: [
                        empty,
                        const Text('Likes-sida'),
                        const Text('Samtal-sida'),
                        const Text('Profil-sida')
                      ])))));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Swipa')).dy, greaterThan(540));
      expect(find.byIcon(Icons.logout), findsNothing);
      if (scale == 1) {
        await tester.ensureVisible(find.text('Ändra filter'));
        expect(tester.getBottomRight(find.text('Ändra filter')).dy,
            lessThan(tester.getTopLeft(find.text('Swipa')).dy - 30));
        await capture(tester, key, 'discovery-navigation');
      }
      await tester.tap(find.text('Chattar'));
      await tester.pumpAndSettle();
      expect(find.text('Samtal-sida'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'full presentation scrolls independently of lifestyle and omits empty sections',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final story =
        List.filled(12, 'Jag tycker om långa samtal, havet och nya platser.')
            .join('\n');
    final p = SwipeProfile.fromJson({
      'bio': story,
      'religion': 'Kristen',
      'workout': 'Ofta',
      'livePlace': 'Stockholm'
    });
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: zulloTheme(),
        home: RepaintBoundary(
            key: key,
            child: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ProfileStory(profile: p))))));
    expect(find.byType(SelectableText), findsOneWidget);
    expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data, story);
    await capture(tester, key, 'presentation');
    await tester.ensureVisible(find.text('Träning: Ofta'));
    expect(find.text('Kristendom'), findsOneWidget);
    expect(find.text('Intressen'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'editor header and preview controls fit enlarged text on a small phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: zulloTheme(),
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: EditProfilePage(authService: PreviewAuth()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Förhandsvisa'));
    await tester.pumpAndSettle();
    expect(find.byType(SwipeProfileCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('profile preview refreshes edited bio and opens the full profile',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: zulloTheme(),
        home: EditProfilePage(
            authService: PreviewAuth(), startInPreviewMode: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Redigera'));
    await tester.pumpAndSettle();
    final input = find
        .descendant(
            of: find.byType(ProfileBasicsSection),
            matching: find.byType(TextField))
        .first;
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Min nya presentation, med plats att läsa.');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('Förhandsvisa'));
    await tester.tap(find.text('Förhandsvisa'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<SwipeProfileCard>(find.byType(SwipeProfileCard))
            .profile
            .bio,
        'Min nya presentation, med plats att läsa.');
    await tester.tap(find.byTooltip('Läs hela profilen'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    await tester.ensureVisible(find.byType(SelectableText));
    expect(
        find.text('Min nya presentation, med plats att läsa.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
