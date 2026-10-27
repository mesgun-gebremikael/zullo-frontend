import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zullo_app/services/notification_access.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/models/chat_open_request.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/chat_cache_service.dart';
import 'package:zullo_app/services/chat_coordinator.dart';
import 'package:zullo_app/services/chat_repository.dart';
import 'package:zullo_app/services/chat_thread_cache_service.dart';
import 'package:zullo_app/services/current_chat.dart';
import 'package:zullo_app/services/matches_cache_service.dart';
import 'package:zullo_app/services/messages_service.dart';
import 'package:zullo_app/services/session_http_client.dart';
import 'package:zullo_app/services/unread_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = AuthStorage();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await storage.clearAuth();
    await storage.saveAuth(token: 'token-A', userId: 'A');
  });

  void populate() {
    ChatCacheService.setMessages('peer', ['private A']);
    ChatThreadCacheService.setThread('peer', ['private A']);
    MatchesCacheService.setData(
      matches: [
        {'userId': 'peer'},
      ],
      likesReceived: ['private A'],
    );
    ChatRepository.instance.setThread('peer', []);
    UnreadSyncService.instance.markChatOpened('peer');
    CurrentChat.openUserId = 'peer';
    ChatCoordinator.instance.requestOpenChat(
      const ChatOpenRequest(
        userId: 'peer',
        displayName: 'Private A',
        photoUrl: '',
      ),
    );
  }

  void expectEmpty() {
    expect(ChatCacheService.getMessages('peer'), isNull);
    expect(ChatThreadCacheService.getThread('peer'), isNull);
    expect(MatchesCacheService.getMatches(), isNull);
    expect(MatchesCacheService.getLikesReceived(), isNull);
    expect(ChatRepository.instance.state.threads, isEmpty);
    expect(ChatRepository.instance.chatList, isEmpty);
    expect(UnreadSyncService.instance.getOpenedAt('peer'), isNull);
    expect(ChatCoordinator.instance.pendingRequest, isNull);
    expect(CurrentChat.openUserId, isNull);
  }

  test(
    'logout immediately clears all private state even while unlink is offline',
    () async {
      populate();
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final auth = AuthService(
        client: MockClient((request) {
          expect(request.headers['Authorization'], 'Bearer token-A');
          started.complete();
          return pending.future;
        }),
      );
      await auth.logout();
      await started.future;
      expectEmpty();
      expect(await storage.getToken(), isNull);
      expect(await storage.getUserId(), isNull);
      pending.completeError(Exception('offline'));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'direct login to B clears A data including same-account re-login',
    () async {
      populate();
      final oldGeneration = AccountSession.generation;
      await storage.saveAuth(token: 'token-B', userId: 'B');
      expectEmpty();
      expect(await storage.getUserId(), 'B');
      expect(AccountSession.isCurrent(oldGeneration), isFalse);
      final bGeneration = AccountSession.generation;
      await storage.saveAuth(token: 'new-token-B', userId: 'B');
      expect(AccountSession.isCurrent(bGeneration), isFalse);
    },
  );

  test('late device unlink cannot erase B credentials', () async {
    final pending = Completer<http.Response>();
    final auth = AuthService(client: MockClient((_) => pending.future));
    await auth.logout();
    await storage.saveAuth(token: 'token-B', userId: 'B');
    pending.complete(http.Response('', 500));
    await Future<void>.delayed(Duration.zero);
    expect(await storage.getUserId(), 'B');
    expect(await storage.getToken(), 'token-B');
  });

  for (final resource in ['matches', 'likes', 'thread']) {
    test('late $resource response is rejected after switching to B', () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final client = MockClient((request) {
        expect(request.headers['Authorization'], 'Bearer token-A');
        started.complete();
        return pending.future;
      });
      final auth = AuthService(client: client);
      final messages = MessagesService('http://test', storage, client: client);
      final future = resource == 'matches'
          ? auth.getMatches()
          : resource == 'likes'
              ? auth.getLikesReceived()
              : messages.getThread('peer');
      final assertion = expectLater(
        future,
        throwsA(isA<SessionChangedException>()),
      );
      await started.future;
      await storage.clearAuth();
      await storage.saveAuth(token: 'token-B', userId: 'B');
      pending.complete(http.Response('[{"text":"private A"}]', 200));
      await assertion;
      expectEmpty();
    });
  }

  test('old service cannot issue a new request with B credentials', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('[]', 200);
    });
    final auth = AuthService(client: client);
    final messages = MessagesService('http://test', storage, client: client);
    await storage.saveAuth(token: 'token-B', userId: 'B');
    await expectLater(
      auth.getMatches(),
      throwsA(isA<SessionChangedException>()),
    );
    await expectLater(
      messages.sendMessage(toUserId: 'peer', text: 'old', clientMessageId: '1'),
      throwsA(isA<SessionChangedException>()),
    );
    expect(requests, 0);
  });

  test(
    'login persists complete identity and permits new-session requests',
    () async {
      final auth = AuthService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({'token': 'token-B', 'userId': 'B'}),
              200,
            );
          }
          expect(request.headers['Authorization'], 'Bearer token-B');
          return http.Response('[{"userId":"peer-B"}]', 200);
        }),
      );
      await auth.login(email: 'b@example.test', password: 'test');
      expect(await storage.getUserId(), 'B');
      expect((await auth.getMatches()).single['userId'], 'peer-B');
    },
  );

  test('incomplete login response does not reuse previous identity', () async {
    final auth = AuthService(
      client: MockClient((_) async => http.Response('{"token":"B"}', 200)),
    );
    await expectLater(
      auth.login(email: 'b@example.test', password: 'test'),
      throwsStateError,
    );
    expect(await storage.getUserId(), 'A');
  });

  test(
    'login response arriving after logout cannot sign user back in',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final auth = AuthService(
        client: MockClient((_) {
          started.complete();
          return pending.future;
        }),
      );
      final login = auth.login(email: 'b@example.test', password: 'test');
      final assertion = expectLater(
        login,
        throwsA(isA<SessionChangedException>()),
      );
      await started.future;
      await storage.clearAuth();
      pending.complete(http.Response('{"token":"B","userId":"B"}', 200));
      await assertion;
      expect(await storage.getToken(), isNull);
    },
  );

  test(
    'concurrent credential writes leave the newest identity intact',
    () async {
      final a = storage.clearAuth();
      final assertion = expectLater(a, throwsA(isA<SessionChangedException>()));
      final b = storage.saveAuth(token: 'token-B', userId: 'B');
      await assertion;
      await b;
      expect(await storage.getToken(), 'token-B');
      expect(await storage.getUserId(), 'B');
    },
  );

  test('notification for A is ignored when B uses the same phone', () async {
    await storage.saveAuth(token: 'token-B', userId: 'B');
    var requests = 0;
    final auth = AuthService(client: MockClient((_) async {
      requests++;
      return http.Response('[]', 200);
    }));
    expect(await NotificationAccess.canOpen('shared-peer', 'A', auth: auth),
        isFalse);
    expect(requests, 0);
    expect(await NotificationAccess.canOpen('shared-peer', 'B', auth: auth),
        isTrue);
    expect(requests, 1);
  });

  test('blocked or unmatched recipient cannot open a notification', () async {
    final auth =
        AuthService(client: MockClient((_) async => http.Response('', 403)));
    expect(await NotificationAccess.canOpen('peer', 'A', auth: auth), isFalse);
  });

  test('notification access granted after a session switch is discarded',
      () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final auth = AuthService(client: MockClient((_) {
      started.complete();
      return pending.future;
    }));
    final access = NotificationAccess.canOpen('peer', 'A', auth: auth);
    await started.future;
    await storage.saveAuth(token: 'token-B', userId: 'B');
    pending.complete(http.Response('[]', 200));
    expect(await access, isFalse);
  });

  test('notifications require an explicit matching recipient', () {
    expect(AccountSession.notificationBelongsTo('A', 'A'), isTrue);
    expect(AccountSession.notificationBelongsTo('A', 'B'), isFalse);
    expect(AccountSession.notificationBelongsTo('A', null), isFalse);
    expect(AccountSession.notificationBelongsTo(null, 'B'), isFalse);
    expect(AccountSession.notificationBelongsTo('', 'B'), isFalse);
  });

  test('response body delayed across session reset is rejected', () async {
    final body = StreamController<List<int>>();
    final client = SessionHttpClient(_StreamingClient(body.stream));
    final future = client.get(Uri.parse('http://test'));
    final assertion = expectLater(
      future,
      throwsA(isA<SessionChangedException>()),
    );
    await Future<void>.delayed(Duration.zero);
    AccountSession.reset();
    body.add(utf8.encode('private A'));
    await body.close();
    await assertion;
    client.close();
  });
}

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.body);
  final Stream<List<int>> body;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(body, 200);
}
