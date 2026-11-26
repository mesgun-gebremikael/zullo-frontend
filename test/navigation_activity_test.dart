import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/main_navigation.dart';
import 'package:zullo_app/matches_page.dart';
import 'package:zullo_app/profile_tab.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/chat_repository.dart';
import 'package:zullo_app/services/commerce_service.dart';
import 'package:zullo_app/services/signalr_service.dart';
import 'package:zullo_app/models/chat_list_item.dart';
import 'package:zullo_app/models/chat_message_item.dart';
import 'support/fake_chat_transport.dart';

class _Auth extends AuthService {
  int profileCalls = 0;
  final Completer<Map<String, dynamic>>? pendingProfile;
  final bool failFirst;
  _Auth({this.pendingProfile, this.failFirst = false});
  @override
  Future<List<dynamic>> getMatches() async => [];
  @override
  Future<Map<String, dynamic>> getMyProfile() {
    profileCalls++;
    if (pendingProfile != null) return pendingProfile!.future;
    if (failFirst && profileCalls == 1) {
      return Future.error(StateError('offline'));
    }
    return Future.value({'displayName': 'My profile', 'photoUrls': []});
  }
}

class _Commerce extends CommerceClient {
  @override
  Future<CommerceState> state() async => const CommerceState();
}

class _DelayedCommerce extends CommerceClient {
  final requests = <Completer<CommerceState>>[];
  @override
  Future<CommerceState> state() {
    final request = Completer<CommerceState>();
    requests.add(request);
    return request.future;
  }
}

class _TickingPage extends StatefulWidget {
  final int index;
  final Map<int, int> ticks;
  const _TickingPage(this.index, this.ticks);
  @override
  State<_TickingPage> createState() => _TickingPageState();
}

class _TickingPageState extends State<_TickingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..addListener(() =>
          widget.ticks.update(widget.index, (n) => n + 1, ifAbsent: () => 1))
      ..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('page-${widget.index}');
}

void main() {
  setUp(AccountSession.reset);
  testWidgets(
      'tab content is retained while hidden and background tickers stop',
      (tester) async {
    final ticks = <int, int>{};
    await tester.pumpWidget(MaterialApp(
        home: MainNavigation(
      authService: _Auth(),
      liveService: SignalRService(transport: FakeChatTransport()),
      pages: List.generate(4, (i) => _TickingPage(i, ticks)),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final firstState = tester.state(find.byType(_TickingPage));
    await tester.tap(find.text('Chattar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final hiddenTicks = ticks[0];
    await tester.pump(const Duration(milliseconds: 32));
    expect(ticks[0], hiddenTicks);
    final activeTicks = ticks[2]!;
    await tester.pump(const Duration(milliseconds: 32));
    expect(ticks[2], greaterThan(activeTicks));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    final pausedTicks = ticks[2];
    await tester.pump(const Duration(milliseconds: 32));
    expect(ticks[2], pausedTicks);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.text('Swipa'));
    await tester.pump();
    expect(tester.state(find.byType(_TickingPage)), same(firstState));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('thread-only updates do not remap the matches list',
      (tester) async {
    var unreadCallbacks = 0;
    await tester.pumpWidget(MaterialApp(
        home: MatchesPage(
      authService: _Auth(),
      onUnreadChanged: (_) => unreadCallbacks++,
    )));
    await tester.pumpAndSettle();
    const row = ChatListItem(
        userId: 'peer',
        displayName: 'Peer',
        photoUrl: '',
        age: 24,
        lastMessageText: '',
        lastMessageAtUtc: null,
        hasUnread: false,
        unreadMessageCount: 0);
    ChatRepository.instance.setChatList([row]);
    await tester.pumpAndSettle();
    final before = unreadCallbacks;
    ChatRepository.instance.setThread('peer', [
      ChatMessageItem(
          text: 'hello',
          isMe: false,
          timeLocal: DateTime(2026),
          readAtLocal: null,
          pending: false,
          failed: false,
          clientMessageId: '1')
    ]);
    await tester.pumpAndSettle();
    expect(unreadCallbacks, before);
    ChatRepository.instance
        .setChatList([row.copyWith(displayName: 'Updated peer')]);
    await tester.pumpAndSettle();
    expect(unreadCallbacks, greaterThan(before));
    expect(find.text('Updated peer'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('profile failure is visible and retry loads profile',
      (tester) async {
    final auth = _Auth(failFirst: true);
    await tester.pumpWidget(MaterialApp(
        home: ProfileTab(authService: auth, commerceClient: _Commerce())));
    await tester.pumpAndSettle();
    expect(find.text('Kunde inte ladda profil'), findsOneWidget);
    await tester.tap(find.text('Försök igen'));
    await tester.pumpAndSettle();
    expect(find.text('My profile'), findsOneWidget);
    expect(auth.profileCalls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('wallet refresh bursts share work without hiding the profile',
      (tester) async {
    final commerce = _DelayedCommerce();
    await tester.pumpWidget(MaterialApp(
        home: ProfileTab(authService: _Auth(), commerceClient: commerce)));
    await tester.pump();
    expect(find.text('My profile'), findsOneWidget);
    expect(commerce.requests, hasLength(1));
    for (var i = 0; i < 20; i++) {
      CommerceEvents.walletChanged();
    }
    await tester.pump();
    expect(commerce.requests, hasLength(1));
    commerce.requests.first.complete(const CommerceState());
    await tester.pump();
    expect(commerce.requests, hasLength(2));
    commerce.requests.last.complete(const CommerceState());
    await tester.pumpAndSettle();
    expect(commerce.requests, hasLength(2));
    expect(find.text('My profile'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late profile response cannot expose the previous account',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(MaterialApp(
        home: ProfileTab(
            authService: _Auth(pendingProfile: pending),
            commerceClient: _Commerce())));
    await tester.pump();
    AccountSession.reset();
    pending.complete({'displayName': 'Previous account', 'photoUrls': []});
    await tester.pumpAndSettle();
    expect(find.text('Previous account'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
