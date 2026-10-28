import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/chat_page.dart';
import 'package:zullo_app/main_navigation.dart';
import 'package:zullo_app/matches_page.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/matches_refresh_service.dart';
import 'package:zullo_app/services/messages_service.dart';
import 'package:zullo_app/services/signalr_service.dart';
import 'support/fake_chat_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'A-token', userId: 'A');
  });
  Future<void> settleIo(
      WidgetTester tester, Future<void> Function() action) async {
    await tester.runAsync(() async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) =>
      settleIo(tester, () => tester.pumpWidget(const SizedBox.shrink()));
  Map<String, dynamic> row(int sequence, String text,
          {bool mine = false, String? key}) =>
      {
        'id': 'id-$sequence',
        'sequence': sequence,
        'text': text,
        'fromUserId': mine ? 'A' : 'B',
        'toUserId': mine ? 'B' : 'A',
        'clientMessageId': key ?? 'client-$sequence',
        'createdAtUtc': '2026-10-28T00:00:00Z',
        'readAtUtc': null,
      };
  http.Response page(List<dynamic> messages,
          {bool more = false, String? cursor, int sequence = 1}) =>
      http.Response(
          jsonEncode({
            'messages': messages,
            'hasMore': more,
            'nextCursor': cursor,
            'latestCursor': 'cursor-$sequence'
          }),
          200);

  testWidgets(
      'failed send retries the same identifier and keeps a single bubble',
      (tester) async {
    final transport = FakeChatTransport();
    final sends = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/thread-page')) {
        return page([row(1, 'Existing')]);
      }
      if (request.url.path.endsWith('/send')) {
        final sent = jsonDecode(request.body) as Map<String, dynamic>;
        sends.add(sent);
        if (sends.length == 1) {
          throw StateError('Simulated lost response after commit');
        }
        return http.Response(
            jsonEncode(
                row(2, sent['text'], mine: true, key: sent['clientMessageId'])),
            200);
      }
      return http.Response('{}', 200);
    });
    await settleIo(
        tester,
        () => tester.pumpWidget(MaterialApp(
                home: ChatPage(
              userId: 'B',
              displayName: 'Peer',
              photoUrl: '',
              messagesService:
                  MessagesService('http://test', AuthStorage(), client: client),
              liveService: SignalRService(transport: transport),
              refreshBadge: () async {},
            ))));
    expect(find.text('Existing'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Retry me');
    await settleIo(tester, () => tester.tap(find.byIcon(Icons.send)));
    expect(find.text('Skicka igen'), findsOneWidget);
    expect(find.text('Retry me'), findsOneWidget);
    await settleIo(tester, () => tester.tap(find.text('Skicka igen')));
    expect(sends.length, 2);
    expect(sends[0]['clientMessageId'], sends[1]['clientMessageId']);
    expect(find.text('Retry me'), findsOneWidget);
    expect(find.text('Skicka igen'), findsNothing);
    await close(tester);
  });

  testWidgets(
      'reconnect snapshot cannot erase a pending send or a live arrival',
      (tester) async {
    final transport = FakeChatTransport();
    final sending = Completer<http.Response>();
    Map<String, dynamic>? sent;
    var historyRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/thread-page')) {
        historyRequests++;
        return page([row(1, 'Existing')]);
      }
      if (request.url.path.endsWith('/send')) {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return sending.future;
      }
      return http.Response('{}', 200);
    });
    await settleIo(
        tester,
        () => tester.pumpWidget(MaterialApp(
                home: ChatPage(
              userId: 'B',
              displayName: 'Peer',
              photoUrl: '',
              messagesService:
                  MessagesService('http://test', AuthStorage(), client: client),
              liveService: SignalRService(transport: transport),
              refreshBadge: () async {},
            ))));
    await tester.enterText(find.byType(TextField), 'Still pending');
    await settleIo(tester, () => tester.tap(find.byIcon(Icons.send)));
    await settleIo(tester, () async {
      transport.messageEvents.add(row(2, 'Arrived live'));
      transport.reconnectEvents.add(null);
    });
    expect(historyRequests, greaterThanOrEqualTo(2));
    expect(find.text('Still pending'), findsOneWidget);
    expect(find.text('Arrived live'), findsOneWidget);
    await settleIo(tester, () async {
      sending.complete(http.Response(
          jsonEncode(row(3, 'Still pending',
              mine: true, key: sent!['clientMessageId'])),
          200));
    });
    expect(find.text('Still pending'), findsOneWidget);
    expect(find.text('Arrived live'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
      'receipt arriving before the HTTP response marks only confirmed earlier sends',
      (tester) async {
    final transport = FakeChatTransport();
    final response = Completer<http.Response>();
    Map<String, dynamic>? sent;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/thread-page')) {
        return page([row(1, 'Existing')]);
      }
      if (request.url.path.endsWith('/send')) {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return response.future;
      }
      return http.Response('{}', 200);
    });
    await settleIo(
        tester,
        () => tester.pumpWidget(MaterialApp(
                home: ChatPage(
              userId: 'B',
              displayName: 'Peer',
              photoUrl: '',
              messagesService:
                  MessagesService('http://test', AuthStorage(), client: client),
              liveService: SignalRService(transport: transport),
              refreshBadge: () async {},
            ))));
    await tester.enterText(find.byType(TextField), 'Already read');
    await settleIo(tester, () => tester.tap(find.byIcon(Icons.send)));
    await settleIo(tester, () async {
      transport.readEvents.add({
        'chatUserId': 'B',
        'readThroughSequence': 2,
        'readAtUtc': '2026-10-28T01:00:00Z'
      });
      await Future<void>.delayed(Duration.zero);
      response.complete(http.Response(
          jsonEncode(row(2, 'Already read',
              mine: true, key: sent!['clientMessageId'])),
          200));
    });
    await settleIo(tester, () async {});
    expect(find.text('Sedd'), findsOneWidget);
    await settleIo(tester, () async {
      transport.messageEvents.add(row(3, 'Later outgoing', mine: true));
    });
    expect(find.text('Sedd'), findsOneWidget);
    expect(find.text('Levererad'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
      'older history loads through the visible control without deleting recent messages',
      (tester) async {
    final transport = FakeChatTransport();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/thread-page')) {
        return request.url.queryParameters['before'] == 'older'
            ? page([row(1, 'Older message')], sequence: 1)
            : page([row(2, 'Recent message')],
                more: true, cursor: 'older', sequence: 2);
      }
      return http.Response('{}', 200);
    });
    await settleIo(
        tester,
        () => tester.pumpWidget(MaterialApp(
                home: ChatPage(
              userId: 'B',
              displayName: 'Peer',
              photoUrl: '',
              messagesService:
                  MessagesService('http://test', AuthStorage(), client: client),
              liveService: SignalRService(transport: transport),
              refreshBadge: () async {},
            ))));
    expect(find.text('Visa äldre meddelanden'), findsOneWidget);
    await settleIo(
        tester, () => tester.tap(find.text('Visa äldre meddelanden')));
    expect(find.text('Older message'), findsOneWidget);
    expect(find.text('Recent message'), findsOneWidget);
    expect(find.text('Visa äldre meddelanden'), findsNothing);
    await close(tester);
  });

  testWidgets(
      'navigation builds tabs lazily and empty match results do not trigger polling',
      (tester) async {
    var calls = 0;
    final builds = <int, int>{};
    final transport = FakeChatTransport();
    final auth = AuthService(client: MockClient((_) async {
      calls++;
      return http.Response('[]', 200);
    }));
    await settleIo(
        tester,
        () => tester.pumpWidget(MaterialApp(
                home: MainNavigation(
              authService: auth,
              liveService: SignalRService(transport: transport),
              pages: List.generate(5, (i) => _CountingPage(i, builds)),
            ))));
    expect(builds, {0: 1});
    expect(calls, 1);
    for (final title in ['Explore', 'Likes', 'Chattar', 'Explore']) {
      await settleIo(tester, () => tester.tap(find.text(title)));
    }
    expect(builds, {0: 1, 1: 1, 2: 1, 3: 1});
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 20));
    expect(calls, 1);
    await close(tester);
  });

  testWidgets(
      'three match views share network work and coalesce a burst of refresh events',
      (tester) async {
    final initial = Completer<http.Response>();
    final started = Completer<void>();
    var matches = 0;
    var likes = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/matches')) {
        matches++;
        if (matches == 1) {
          started.complete();
          return initial.future;
        }
        return http.Response('[]', 200);
      }
      likes++;
      return http.Response('[]', 200);
    });
    addTearDown(() {
      if (!initial.isCompleted) initial.complete(http.Response('[]', 200));
    });
    await tester.pumpWidget(MaterialApp(
        home: IndexedStack(
            children: List.generate(
                3,
                (_) =>
                    MatchesPage(authService: AuthService(client: client))))));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(started.isCompleted, isTrue);
    for (var i = 0; i < 30; i++) {
      MatchesRefreshService.instance.requestRefresh();
    }
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    initial.complete(http.Response('[]', 200));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(matches, 2); // Original snapshot plus one invalidated follow-up.
    expect(likes, 2);
    await close(tester);
  });
}

class _CountingPage extends StatefulWidget {
  final int index;
  final Map<int, int> builds;
  const _CountingPage(this.index, this.builds);
  @override
  State<_CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<_CountingPage> {
  @override
  void initState() {
    super.initState();
    widget.builds.update(widget.index, (value) => value + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('page-${widget.index}'));
}
