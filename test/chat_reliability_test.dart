import 'package:zullo_app/services/chat_cache_service.dart';
import 'package:zullo_app/services/chat_repository.dart';
import 'package:zullo_app/services/chat_thread_cache_service.dart';
import 'package:zullo_app/services/current_chat.dart';
import 'package:zullo_app/services/matches_refresh_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/models/chat_message_item.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/api_config.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/chat_merge.dart';
import 'package:zullo_app/services/messages_service.dart';
import 'package:zullo_app/services/refresh_coordinator.dart';
import 'package:zullo_app/services/signalr_service.dart';
import 'package:zullo_app/services/thread_history.dart';
import 'support/fake_chat_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'A-token', userId: 'A');
  });

  test(
      'a burst shares one refresh and one follow-up captures mid-flight invalidation',
      () async {
    final coordinator = RefreshCoordinator();
    final gates = [Completer<void>(), Completer<void>()];
    final starts = [Completer<void>(), Completer<void>()];
    var calls = 0;
    Future<void> load() async {
      final i = calls++;
      starts[i].complete();
      await gates[i].future;
    }

    final first = coordinator.run(load);
    await starts[0].future;
    final burst =
        List.generate(30, (_) => coordinator.run(load, invalidate: true));
    expect(burst.every((f) => identical(f, first)), isTrue);
    gates[0].complete();
    await starts[1].future;
    expect(calls, 2);
    gates[1].complete();
    await Future.wait([first, ...burst]);
    expect(calls, 2);
  });

  test('failed refresh clears in-flight state and the next refresh can succeed',
      () async {
    final coordinator = RefreshCoordinator();
    await expectLater(coordinator.run(() async => throw StateError('offline')),
        throwsStateError);
    var ran = false;
    await coordinator.run(() async {
      ran = true;
    });
    expect(ran, isTrue);
  });

  for (final likes in [false, true]) {
    test(
        'different auth services share an in-flight ${likes ? 'likes' : 'matches'} request',
        () async {
      final gate = Completer<http.Response>();
      final started = Completer<void>();
      var calls = 0;
      final client = MockClient((_) {
        calls++;
        started.complete();
        return gate.future;
      });
      final services = List.generate(20, (_) => AuthService(client: client));
      final futures = services
          .map((s) => likes ? s.getLikesReceived() : s.getMatches())
          .toList();
      await started.future;
      gate.complete(http.Response('[{"userId":"peer"}]', 200));
      final result = await Future.wait(futures);
      expect(calls, 1);
      expect(result.every((rows) => rows.single['userId'] == 'peer'), isTrue);
    });
  }

  test('an old service cannot evict a newer account in-flight request',
      () async {
    final old = AuthService(
        client: MockClient((_) async => throw StateError('must not call')));
    await AuthStorage().saveAuth(token: 'B-token', userId: 'B');
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    var calls = 0;
    final client = MockClient((_) {
      calls++;
      started.complete();
      return gate.future;
    });
    final first = AuthService(client: client).getMatches();
    await started.future;
    await expectLater(
        old.getMatches(), throwsA(isA<SessionChangedException>()));
    final second = AuthService(client: client).getMatches();
    gate.complete(http.Response('[]', 200));
    await Future.wait([first, second]);
    expect(calls, 1);
  });

  Map<String, dynamic> row(int sequence, {String? readAt}) => {
        'id': 'server-$sequence',
        'sequence': sequence,
        'clientMessageId': 'client-$sequence',
        'fromUserId': 'B',
        'toUserId': 'A',
        'text': 'Message $sequence',
        'createdAtUtc': '2026-10-28T00:00:00Z',
        'readAtUtc': readAt,
      };
  http.Response page(List<dynamic> rows,
          {String? next, String? latest, int? readThrough}) =>
      http.Response(
          jsonEncode({
            'messages': rows,
            'hasMore': next != null,
            'nextCursor': next,
            'latestCursor': latest,
            'outgoingReadThrough': readThrough,
            'outgoingReadAtUtc':
                readThrough == null ? null : '2026-10-28T01:00:00Z',
          }),
          200);

  test(
      'history loads bounded pages, catches up forward, and merges duplicate IDs',
      () async {
    var calls = 0;
    final service = MessagesService('http://test', AuthStorage(),
        client: MockClient((request) async {
      calls++;
      final query = request.url.queryParameters;
      expect(query['take'], '50');
      if (query['before'] == 'older') {
        return page([row(1), row(2)], latest: '2', readThrough: 1);
      }
      if (query['after'] == '3') {
        return page([row(4)], next: '4', latest: '4', readThrough: 3);
      }
      if (query['after'] == '4') {
        return page([row(4), row(5)], latest: '5', readThrough: 4);
      }
      return page([row(2), row(3)], next: 'older', latest: '3');
    }));
    final history = ThreadHistory(service, 'B');
    expect((await history.synchronize()).length, 2);
    expect(history.hasOlder, isTrue);
    await history.loadOlder();
    expect(history.hasOlder, isFalse);
    await history.synchronize();
    expect(history.rows.map((m) => m['sequence']), [1, 2, 3, 4, 5]);
    expect(history.outgoingReadThrough, 4);
    expect(calls, 4);
  });

  test('empty conversation can catch up messages after first load', () async {
    var calls = 0;
    final service = MessagesService('http://test', AuthStorage(),
        client: MockClient((request) async {
      calls++;
      return calls == 1
          ? page([], latest: 'zero')
          : page([row(1)], latest: 'one');
    }));
    final history = ThreadHistory(service, 'B');
    expect(await history.synchronize(), isEmpty);
    expect((await history.synchronize()).single['sequence'], 1);
  });

  test(
      'concurrent history loads coalesce and older work queues after initial load',
      () async {
    final firstResponse = Completer<http.Response>();
    final started = Completer<void>();
    var calls = 0;
    final service = MessagesService('http://test', AuthStorage(),
        client: MockClient((request) {
      calls++;
      if (calls == 1) {
        started.complete();
        return firstResponse.future;
      }
      expect(request.url.queryParameters['before'], 'older');
      return Future.value(page([row(1)], latest: 'one'));
    }));
    final history = ThreadHistory(service, 'B');
    final first = history.synchronize();
    await started.future;
    final duplicate = history.synchronize();
    final older = history.loadOlder();
    firstResponse.complete(page([row(2)], next: 'older', latest: 'two'));
    await Future.wait([first, duplicate, older]);
    expect(calls, 2);
    expect(history.rows.map((m) => m['sequence']), [1, 2]);
  });

  test('history failure retains already loaded rows and can be retried',
      () async {
    var calls = 0;
    final service = MessagesService('http://test', AuthStorage(),
        client: MockClient((_) async {
      calls++;
      if (calls == 2) return http.Response('', 500);
      return page([row(calls == 1 ? 1 : 2)], latest: '$calls');
    }));
    final history = ThreadHistory(service, 'B');
    await history.synchronize();
    await expectLater(history.synchronize(), throwsException);
    expect(history.rows.single['sequence'], 1);
    await history.synchronize();
    expect(history.rows.length, 2);
  });

  test('raw merging preserves read receipts against stale snapshots', () {
    final merged =
        mergeThreadRows([row(1, readAt: '2026-10-28T01:00:00Z')], [row(1)]);
    expect(merged.length, 1);
    expect(merged.single['readAtUtc'], isNotNull);
  });

  ChatMessageItem item(
          {String? id,
          int? sequence,
          String key = 'key',
          bool me = true,
          bool pending = false,
          bool failed = false,
          DateTime? read}) =>
      ChatMessageItem(
        serverId: id,
        sequence: sequence,
        text: 'Hello',
        isMe: me,
        timeLocal: DateTime.utc(2026, 10, 28),
        readAtLocal: read,
        pending: pending,
        failed: failed,
        clientMessageId: key,
      );

  test(
      'optimistic delivery reconciles once with server ID without losing a read receipt',
      () {
    final read = DateTime.utc(2026, 10, 28, 1);
    final result = mergeChatItems(
        [item(pending: true, read: read)], [item(id: 'server', sequence: 1)]);
    expect(result.length, 1);
    expect(result.single.serverId, 'server');
    expect(result.single.pending, isFalse);
    expect(result.single.readAtLocal, read);
  });

  test(
      'stale snapshot cannot erase failed or live messages or downgrade confirmation',
      () {
    final result = mergeChatItems(
        [item(id: 'live', sequence: 2, key: 'live'), item(failed: true)],
        [item(id: 'old', sequence: 1, key: 'old')]);
    expect(result.length, 3);
    expect(result.last.failed, isTrue);
    final confirmed = mergeChatItems(
        [item(id: 'server', sequence: 1)], [item(pending: true)]);
    expect(confirmed.single.serverId, 'server');
    expect(confirmed.single.pending, isFalse);
  });

  test(
      'different participants and distinct legacy server rows never collapse by client key',
      () {
    expect(
        mergeChatItems(
            [item(id: 'a', sequence: 1)], [item(id: 'b', sequence: 2)]).length,
        2);
    expect(mergeChatItems([item(me: false)], [item()]).length, 2);
  });

  test(
      'concurrent connects share one handshake and offline startup can be retried',
      () async {
    final transport = FakeChatTransport()..connectGate = Completer<void>();
    final service = SignalRService(transport: transport);
    final first = service.connect();
    await transport.connectStarted.future;
    final others = List.generate(10, (_) => service.connect());
    transport.connectGate!.complete();
    await Future.wait([first, ...others]);
    expect(transport.connections, 1);
    expect(transport.token, 'A-token');
    await service.dispose();
    final offline = FakeChatTransport()..failAttempts = 1;
    final retry = SignalRService(transport: offline);
    await expectLater(retry.connect(), throwsStateError);
    await retry.connect();
    expect(offline.connections, 2);
    await retry.dispose();
  });

  test(
      'logout during handshake stops the late connection and filters old events',
      () async {
    final transport = FakeChatTransport()..connectGate = Completer<void>();
    final service = SignalRService(transport: transport);
    var received = 0;
    final subscription = service.messagesStream.listen((_) => received++);
    final connecting = service.connect();
    final rejected =
        expectLater(connecting, throwsA(isA<SessionChangedException>()));
    await transport.connectStarted.future;
    await AuthStorage().clearAuth();
    transport.connectGate!.complete();
    await rejected;
    transport.messageEvents.add({'text': 'old-account'});
    await Future<void>.delayed(Duration.zero);
    expect(received, 0);
    expect(transport.connected, isFalse);
    await subscription.cancel();
    await service.dispose();
  });

  test('timed-out handshake cannot close a newer successful connection',
      () async {
    final oldHandshake = Completer<void>();
    final transport = FakeChatTransport()..connectGate = oldHandshake;
    final service = SignalRService(
        transport: transport,
        connectionTimeout: const Duration(milliseconds: 20));
    await expectLater(service.connect(), throwsA(isA<TimeoutException>()));
    transport.connectGate = null;
    await service.connect();
    expect(transport.connected, isTrue);
    oldHandshake.complete();
    await Future<void>.delayed(Duration.zero);
    expect(transport.connected, isTrue);
    await service.dispose();
  });

  test(
      'read watermark survives early receipts and never acknowledges a newer message',
      () {
    final receipt = ReadWatermark();
    final at = DateTime.utc(2026, 10, 28, 1);
    receipt.accept(20, at);
    expect(
        receipt.apply(item(id: 'old', sequence: 20)).readAtLocal, at.toLocal());
    expect(receipt.apply(item(id: 'new', sequence: 21)).readAtLocal, isNull);
    expect(
        receipt
            .apply(item(id: 'incoming', sequence: 19, me: false))
            .readAtLocal,
        isNull);
    receipt.accept(10, at.subtract(const Duration(minutes: 5)));
    expect(receipt.through, 20);
    expect(receipt.at, at.toLocal());
  });

  test(
      'retained caches are bounded while an active view can merge older loaded history',
      () {
    final history = List.generate(
        300, (i) => item(id: 'id-$i', sequence: i + 1, key: 'key-$i'));
    CurrentChat.openUserId = 'active';
    ChatRepository.instance.setThread('active', history);
    ChatCacheService.setMessages('active', history);
    ChatThreadCacheService.setThread(
        'active', List.generate(300, (i) => row(i + 1)));
    expect(ChatRepository.instance.threadFor('active').length, 200);
    expect(ChatCacheService.getMessages('active')!.length, 200);
    expect(ChatThreadCacheService.getThread('active')!.length, 200);
    for (var i = 0; i < 25; i++) {
      ChatRepository.instance
          .setThread('peer-$i', [item(id: 'peer-$i', sequence: i + 1)]);
      ChatCacheService.setMessages('peer-$i', [i]);
      ChatThreadCacheService.setThread('peer-$i', [row(i + 1)]);
    }
    expect(ChatRepository.instance.state.threads.length, 20);
    expect(ChatRepository.instance.threadFor('active').length, 200);
    expect(ChatCacheService.getMessages('active'), isNotNull);
    expect(ChatThreadCacheService.getThread('active'), isNotNull);
    expect(ChatCacheService.getMessages('peer-0'), isNull);
    expect(
        mergeChatItems(history, ChatRepository.instance.threadFor('active'))
            .length,
        300);
  });

  test(
      'queued refresh from an old account is discarded without losing the new refresh',
      () async {
    var events = 0;
    final subscription =
        MatchesRefreshService.instance.stream.listen((_) => events++);
    MatchesRefreshService.instance.requestRefresh();
    AccountSession.reset();
    MatchesRefreshService.instance.requestRefresh();
    await Future<void>.delayed(Duration.zero);
    expect(events, 1);
    await subscription.cancel();
  });

  for (final url in [
    'http://example.test',
    'https://user:password@example.test',
    'https://example.test?token=x',
    'not-a-url'
  ]) {
    test('release API configuration rejects $url', () {
      expect(() => ApiConfig.normalize(url, release: true), throwsStateError);
    });
  }
  test(
      'development URL is preserved and production URL normalizes trailing slash',
      () {
    expect(ApiConfig.normalize('http://10.0.2.2:5125/', release: false),
        'http://10.0.2.2:5125');
    expect(ApiConfig.normalize('https://api.example.test/', release: true),
        'https://api.example.test');
  });
}
