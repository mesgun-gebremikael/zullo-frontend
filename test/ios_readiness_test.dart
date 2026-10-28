import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/firebase_options.dart';
import 'package:zullo_app/services/ios_firebase_options.dart';
import 'package:zullo_app/services/push_token_service.dart';

void main() {
  Map<String, String> settings() => {
        'ZULLO_IOS_FIREBASE_API_KEY': 'test-public-client-key',
        'ZULLO_IOS_FIREBASE_APP_ID': '1:123456:ios:abcdef123456',
        'ZULLO_IOS_FIREBASE_SENDER_ID': '123456',
        'ZULLO_IOS_FIREBASE_PROJECT_ID': 'synthetic-test-project',
        'ZULLO_IOS_BUNDLE_ID': 'test.zullo.app',
      };
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
      'registered iOS settings are preserved without inventing app identifiers',
      () {
    final options = IosFirebaseOptions.fromValues(settings());
    expect(options.appId, '1:123456:ios:abcdef123456');
    expect(options.iosBundleId, 'test.zullo.app');
    expect(options.projectId, 'synthetic-test-project');
    expect(options.messagingSenderId, '123456');
  });
  for (final key in IosFirebaseOptions.configured.keys) {
    test('missing $key fails with a useful configuration error', () {
      final values = settings()..remove(key);
      expect(
          () => IosFirebaseOptions.fromValues(values),
          throwsA(isA<StateError>()
              .having((e) => e.message, 'message', contains(key))));
    });
  }
  test('Android Firebase identifiers cannot masquerade as an iOS registration',
      () {
    final values = settings()
      ..['ZULLO_IOS_FIREBASE_APP_ID'] = '1:123456:android:abcdef';
    expect(() => IosFirebaseOptions.fromValues(values), throwsStateError);
  });
  test('sender and registered app must belong together', () {
    final values = settings()..['ZULLO_IOS_FIREBASE_SENDER_ID'] = '987654';
    expect(() => IosFirebaseOptions.fromValues(values), throwsStateError);
  });
  test('bundle identifier rejects whitespace and path values', () {
    final values = settings()..['ZULLO_IOS_BUNDLE_ID'] = 'not a/bundle';
    expect(() => IosFirebaseOptions.fromValues(values), throwsStateError);
  });
  test('Android still uses its existing Firebase options', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(DefaultFirebaseOptions.currentPlatform,
        same(DefaultFirebaseOptions.android));
  });
  test('iOS reports missing configuration instead of unsupported platform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(() => DefaultFirebaseOptions.currentPlatform, throwsStateError);
  });
  test('Android fetches FCM without touching APNs', () async {
    final service = PushTokenService(
        waitForApns: false,
        getApnsToken: () async =>
            throw StateError('Android must not call APNs'),
        getFcmToken: () async => 'android-token');
    expect(await service.load(), 'android-token');
  });
  test('iOS waits for APNs before asking Firebase for a token', () async {
    final events = <String>[];
    var attempts = 0;
    final service = PushTokenService(
        waitForApns: true,
        getApnsToken: () async {
          events.add('apns');
          return ++attempts == 2 ? 'apple-token' : null;
        },
        getFcmToken: () async {
          events.add('fcm');
          return 'ios-token';
        },
        delay: (_) async {
          events.add('wait');
        });
    expect(await service.load(), 'ios-token');
    expect(events, ['apns', 'wait', 'apns', 'fcm']);
  });
  test('missing APNs does not request FCM or prevent startup', () async {
    var attempts = 0;
    final service = PushTokenService(
        waitForApns: true,
        getApnsToken: () async {
          attempts++;
          return null;
        },
        getFcmToken: () async => throw StateError('APNs is not ready'),
        delay: (_) async {});
    expect(await service.load(), isNull);
    expect(attempts, 3);
  });
  test('Firebase failure is recoverable', () async {
    final service = PushTokenService(
        waitForApns: false,
        getApnsToken: () async => null,
        getFcmToken: () async => throw StateError('Offline'));
    expect(await service.load(), isNull);
  });
  test('slow Firebase request is bounded', () async {
    final service = PushTokenService(
        waitForApns: false,
        getApnsToken: () async => null,
        getFcmToken: () => Completer<String?>().future,
        timeout: const Duration(milliseconds: 10));
    expect(await service.load(), isNull);
  });
  test('slow APNs request is bounded without requesting FCM', () async {
    var fcmRequested = false;
    final service = PushTokenService(
        waitForApns: true,
        getApnsToken: () => Completer<String?>().future,
        getFcmToken: () async {
          fcmRequested = true;
          return 'wrong';
        },
        timeout: const Duration(milliseconds: 10));
    expect(await service.load(), isNull);
    expect(fcmRequested, isFalse);
  });
}
