import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/models/chat_open_request.dart';
import 'package:zullo_app/models/swipe_profile.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/match_notification_handler.dart';
import 'package:zullo_app/services/notification_startup.dart';

RemoteMessage notice(
        {String recipient = 'recipient',
        String event = 'match-pair',
        String type = 'match'}) =>
    RemoteMessage(data: {
      'type': type,
      'matchId': 'pair',
      'eventId': event,
      'senderUserId': 'peer',
      'recipientUserId': recipient,
      'senderName': 'UNTRUSTED NAME',
      'senderPhotoUrl': 'untrusted-photo',
      'messageText': 'UNTRUSTED MESSAGE',
    });
SwipeProfile person([String peer = 'peer']) => SwipeProfile.fromJson({
      'userId': peer,
      'displayName': 'Allowed profile',
      'age': 27,
      'photoUrls': ['authorized-photo'],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'match opening resolves authorized identity rather than untrusted push copy',
      () async {
    final request = await MatchNotificationHandler(
      canOpen: (peer, recipient) async =>
          peer == 'peer' && recipient == 'recipient',
      profile: (peer) async => person(),
    ).resolve(notice());
    expect(request?.userId, 'peer');
    expect(request?.displayName, 'Allowed profile');
    expect(request?.photoUrl, 'authorized-photo');
    expect(request?.previewMessageText, isNull);
    expect(request?.forceRefreshThread, isTrue);
  });
  test(
      'wrong recipient, revoked relation and closed account cannot fetch profile',
      () async {
    var reads = 0;
    final handler = MatchNotificationHandler(
      canOpen: (_, recipient) async => recipient == 'recipient',
      profile: (_) async {
        reads++;
        return person();
      },
    );
    expect(await handler.resolve(notice(recipient: 'another-account')), isNull);
    expect(reads, 0);
    expect(
        await MatchNotificationHandler(
            canOpen: (unusedPeer, unusedRecipient) async => false,
            profile: (_) async {
              reads++;
              return person();
            }).resolve(notice()),
        isNull);
    expect(reads, 0);
  });
  test('invalid type or inconsistent event identity never passes access gate',
      () async {
    var checks = 0;
    final handler = MatchNotificationHandler(
        canOpen: (unusedPeer, unusedRecipient) async {
          checks++;
          return true;
        },
        profile: (_) async => person());
    expect(await handler.resolve(notice(type: 'message')), isNull);
    expect(await handler.resolve(notice(event: 'other-event')), isNull);
    expect(checks, 0);
  });
  test('a changed account while checking access discards the event', () async {
    final check = Completer<bool>();
    var reads = 0;
    final pending = MatchNotificationHandler(
        canOpen: (unusedPeer, unusedRecipient) => check.future,
        profile: (_) async {
          reads++;
          return person();
        }).resolve(notice());
    AccountSession.reset();
    check.complete(true);
    expect(await pending, isNull);
    expect(reads, 0);
  });
  test('changed session or revoked profile after authorization stays closed',
      () async {
    final profile = Completer<SwipeProfile>();
    final pending = MatchNotificationHandler(
        canOpen: (unusedPeer, unusedRecipient) async => true,
        profile: (_) => profile.future).resolve(notice());
    await Future<void>.delayed(Duration.zero);
    AccountSession.reset();
    profile.complete(person());
    expect(await pending, isNull);
    expect(
        await MatchNotificationHandler(
                canOpen: (unusedPeer, unusedRecipient) async => true,
                profile: (_) async => throw StateError('revoked'))
            .resolve(notice()),
        isNull);
    expect(
        await MatchNotificationHandler(
            canOpen: (unusedPeer, unusedRecipient) async => true,
            profile: (_) async => person('unexpected-peer')).resolve(notice()),
        isNull);
  });
  test('cold match lookup queues once without waiting for push registration',
      () async {
    final registration = Completer<void>();
    final requests = <ChatOpenRequest>[];
    final handler = MatchNotificationHandler(
        canOpen: (unusedPeer, unusedRecipient) async => true,
        profile: (_) async => person());
    final startup = NotificationStartup(
        register: () => registration.future,
        initialMessage: () async => notice(),
        resolveMatch: handler.resolve,
        enqueue: requests.add);
    await startup.start();
    await startup.start();
    expect(registration.isCompleted, isFalse);
    expect(requests.single.displayName, 'Allowed profile');
    expect(requests.single.previewMessageText, isNull);
    registration.complete();
  });
  test('cold match cannot queue a lookup belonging to a previous session',
      () async {
    final resolved = Completer<ChatOpenRequest?>();
    final requests = <ChatOpenRequest>[];
    final pending = NotificationStartup(
            register: () async {},
            initialMessage: () async => notice(),
            resolveMatch: (_) => resolved.future,
            enqueue: requests.add)
        .start();
    await Future<void>.delayed(Duration.zero);
    AccountSession.reset();
    resolved.complete(const ChatOpenRequest(
        userId: 'peer', displayName: 'Old', photoUrl: ''));
    await pending;
    expect(requests, isEmpty);
  });
}
