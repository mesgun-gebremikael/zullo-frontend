import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/models/chat_open_request.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/chat_coordinator.dart';
import 'package:zullo_app/services/notification_access.dart';
import 'package:zullo_app/services/notification_startup.dart';

class _NotificationAuth extends AuthService {
  final peers = <String>[];
  bool allowed = true;
  @override
  Future<bool> canOpenChat(String peer) async {
    peers.add(peer);
    return allowed;
  }
}

RemoteMessage _message({String recipient = 'A', String peer = 'peer'}) =>
    RemoteMessage(messageId: 'cold-message', data: {
      'type': 'message',
      'recipientUserId': recipient,
      'senderUserId': peer,
      'senderName': 'Untranslated sender',
      'senderPhotoUrl': 'https://photos.example.test/peer.jpg',
      'messageText': 'Untranslated message',
    });

class _StartupHost extends StatefulWidget {
  const _StartupHost(this.startup);
  final NotificationStartup startup;
  @override
  State<_StartupHost> createState() => _StartupHostState();
}

class _StartupHostState extends State<_StartupHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.startup.start());
    });
  }

  @override
  Widget build(BuildContext context) => const Text('normal startup screen');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'token-A', userId: 'A');
    ChatCoordinator.instance.clearPendingRequest();
  });
  tearDown(() => ChatCoordinator.instance.clearPendingRequest());

  testWidgets(
      'first frame and initial lookup do not wait for registration or APNs',
      (tester) async {
    final registration = Completer<void>();
    final initial = Completer<RemoteMessage?>();
    final access = Completer<bool>();
    final requests = <ChatOpenRequest>[];
    var lookedUp = false;
    final startup = NotificationStartup(
        register: () => registration.future,
        initialMessage: () {
          lookedUp = true;
          return initial.future;
        },
        canOpen: (_, __) => access.future,
        enqueue: requests.add);
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: _StartupHost(startup))));
    expect(find.text('normal startup screen'), findsOneWidget);
    expect(lookedUp, isTrue);
    expect(registration.isCompleted, isFalse);
    initial.complete(_message());
    await tester.pump();
    expect(requests, isEmpty,
        reason: 'Access must be verified before queuing.');
    access.complete(true);
    await tester.pump();
    expect(requests.single.userId, 'peer');
    expect(registration.isCompleted, isFalse);
    // Queuing a cold notification must not replace login/profile/startup routes.
    expect(find.text('normal startup screen'), findsOneWidget);
    registration.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('authorized cold notification queues the correct peer exactly once',
      () async {
    final auth = _NotificationAuth();
    final startup = NotificationStartup(
      register: () async {},
      initialMessage: () async => _message(),
      canOpen: (peer, recipient) =>
          NotificationAccess.canOpen(peer, recipient, auth: auth),
    );
    await startup.start();
    await startup.start();
    expect(auth.peers, ['peer']);
    final queued = ChatCoordinator.instance.consumePendingRequest()!;
    expect(queued.userId, 'peer');
    expect(queued.displayName, 'Untranslated sender');
    expect(queued.previewMessageText, 'Untranslated message');
    expect(queued.photoUrl, 'https://photos.example.test/peer.jpg');
    expect(queued.fromNotification, isTrue);
    expect(queued.forceRefreshThread, isTrue);
    expect(queued.openChatsListOnExit, isTrue);
    expect(ChatCoordinator.instance.consumePendingRequest(), isNull);
  });

  test('recipient mismatch is rejected before asking about the peer', () async {
    final auth = _NotificationAuth();
    await NotificationStartup(
      register: () async {},
      initialMessage: () async => _message(recipient: 'B'),
      canOpen: (peer, recipient) =>
          NotificationAccess.canOpen(peer, recipient, auth: auth),
    ).start();
    expect(auth.peers, isEmpty);
    expect(ChatCoordinator.instance.pendingRequest, isNull);
  });

  test('blocked or no-longer-matched peer cannot be queued', () async {
    final auth = _NotificationAuth()..allowed = false;
    await NotificationStartup(
      register: () async {},
      initialMessage: () async => _message(),
      canOpen: (peer, recipient) =>
          NotificationAccess.canOpen(peer, recipient, auth: auth),
    ).start();
    expect(auth.peers, ['peer']);
    expect(ChatCoordinator.instance.pendingRequest, isNull);
  });

  test('session change during access verification discards the cold request',
      () async {
    final checking = Completer<bool>();
    final startedChecking = Completer<void>();
    final startup = NotificationStartup(
      register: () async {},
      initialMessage: () async => _message(),
      canOpen: (_, __) {
        startedChecking.complete();
        return checking.future;
      },
    );
    final starting = startup.start();
    await startedChecking.future;
    AccountSession.reset();
    checking.complete(true);
    await starting;
    expect(ChatCoordinator.instance.pendingRequest, isNull);
  });

  test('session change during initial lookup never asks about the old account',
      () async {
    final initial = Completer<RemoteMessage?>();
    var checks = 0;
    final starting = NotificationStartup(
      register: () async {},
      initialMessage: () => initial.future,
      canOpen: (_, __) async {
        checks++;
        return true;
      },
    ).start();
    AccountSession.reset();
    initial.complete(_message());
    await starting;
    expect(checks, 0);
    expect(ChatCoordinator.instance.pendingRequest, isNull);
  });

  test('registration failure does not discard an accessible cold notification',
      () async {
    await NotificationStartup(
      register: () async => throw StateError('registration unavailable'),
      initialMessage: () async => _message(),
      canOpen: (_, __) async => true,
    ).start();
    expect(ChatCoordinator.instance.pendingRequest?.userId, 'peer');
  });

  testWidgets('initial lookup is bounded and never delays the visible app',
      (tester) async {
    final pending = Completer<RemoteMessage?>();
    var complete = false;
    final startup = NotificationStartup(
      register: () async {},
      initialMessage: () => pending.future,
      canOpen: (_, __) async => true,
    );
    await tester.pumpWidget(const MaterialApp(home: Text('visible app')));
    unawaited(startup.start().then((_) => complete = true));
    await tester.pump(const Duration(seconds: 5));
    expect(complete, isTrue);
    expect(find.text('visible app'), findsOneWidget);
    expect(ChatCoordinator.instance.pendingRequest, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final message in [
    const RemoteMessage(data: {'type': 'super_like'}),
    const RemoteMessage(data: {
      'type': 'message',
      'recipientUserId': 'A',
    }),
    const RemoteMessage(data: {
      'type': 'message',
      'recipientUserId': 'A',
      'senderUserId': ' ',
    }),
    const RemoteMessage(data: {
      'type': 'message',
      'senderUserId': 'peer',
    }),
  ]) {
    test('malformed/non-chat payload cannot queue a chat: ${message.data}',
        () async {
      var checks = 0;
      await NotificationStartup(
        register: () async {},
        initialMessage: () async => message,
        canOpen: (_, __) async {
          checks++;
          return true;
        },
      ).start();
      expect(checks, 0);
      expect(ChatCoordinator.instance.pendingRequest, isNull);
    });
  }
}
