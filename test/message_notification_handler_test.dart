import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/models/swipe_profile.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/message_notification_handler.dart';

RemoteMessage notice() => const RemoteMessage(data: {
      'type': 'message',
      'senderUserId': 'peer',
      'recipientUserId': 'me',
      'senderName': 'Spoofed push name',
      'senderPhotoUrl': 'untrusted',
      'messageText': 'private preview',
    });
SwipeProfile person([String id = 'peer']) => SwipeProfile.fromJson({
      'userId': id,
      'displayName': 'Trusted name',
      'photoUrls': ['trusted-photo']
    });

void main() {
  setUp(AccountSession.reset);
  test(
      'IDs-only push resolves identity from authorized profile and never preview data',
      () async {
    final order = <String>[];
    final request =
        await MessageNotificationHandler(canOpen: (peer, recipient) async {
      expect((peer, recipient), ('peer', 'me'));
      order.add('access');
      return true;
    }, profile: (_) async {
      order.add('profile');
      return person();
    }).resolve(notice());
    expect(order, ['access', 'profile']);
    expect(request!.displayName, 'Trusted name');
    expect(request.photoUrl, 'trusted-photo');
    expect(request.previewMessageText, isNull);
    expect(request.forceRefreshThread, isTrue);
  });
  test('recipient/relation refusal never fetches identity', () async {
    var fetched = false;
    final request = await MessageNotificationHandler(
        canOpen: (_, __) async => false,
        profile: (_) async {
          fetched = true;
          return person();
        }).resolve(notice());
    expect(request, isNull);
    expect(fetched, isFalse);
  });
  test('account switch during access check blocks profile lookup', () async {
    final access = Completer<bool>();
    var fetched = false;
    final pending = MessageNotificationHandler(
        canOpen: (_, __) => access.future,
        profile: (_) async {
          fetched = true;
          return person();
        }).resolve(notice());
    AccountSession.reset();
    access.complete(true);
    expect(await pending, isNull);
    expect(fetched, isFalse);
  });
  test('account switch or mismatched fetched identity cannot open a chat',
      () async {
    final profile = Completer<SwipeProfile>();
    final pending = MessageNotificationHandler(
        canOpen: (_, __) async => true,
        profile: (_) => profile.future).resolve(notice());
    await Future<void>.delayed(Duration.zero);
    AccountSession.reset();
    profile.complete(person());
    expect(await pending, isNull);
    expect(
        await MessageNotificationHandler(
            canOpen: (_, __) async => true,
            profile: (_) async => person('another')).resolve(notice()),
        isNull);
  });
}
