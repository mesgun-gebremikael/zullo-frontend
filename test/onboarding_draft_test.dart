import 'support/draft_fakes.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/onboarding_draft_service.dart';
import 'package:zullo_app/onboarding/profile_setup_controller.dart';
import 'package:zullo_app/onboarding/onboarding_data.dart';
import 'package:zullo_app/onboarding/onboarding_steps.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    AccountSession.reset();
    FlutterSecureStorage.setMockInitialValues({});
  });
  test('draft HTTP is authenticated, private and revision-bound', () async {
    final calls = <String>[];
    final service = OnboardingDraftService(
        storage: DraftStorage(),
        client: MockClient((request) async {
          calls.add(request.method);
          expect(request.url.path, '/me/onboarding');
          expect(request.headers['Authorization'], 'Bearer token-A');
          if (request.method == 'GET') return http.Response('{}', 404);
          expect(jsonDecode(request.body), {
            'revision': 0,
            'step': 2,
            'data': {'displayName': 'Anna'}
          });
          return http.Response(
              '{"revision":1,"step":2,"data":{"displayName":"Anna"}}', 200);
        }));
    expect(await service.load(), isNull);
    expect((await service.save(0, 2, {'displayName': 'Anna'})).revision, 1);
    expect(calls, ['GET', 'PUT']);
  });
  test('new instance restores answers and position from the account', () async {
    final service = FakeDraftService(storage: DraftStorage())
      ..remote = const DraftSnapshot(
          4, 7, {'displayName': 'Anna', 'livePlace': 'Stockholm'});
    final controller =
        await ProfileSetupController.load(service, cache: MemoryDraftCache());
    addTearDown(controller.dispose);
    expect(controller.data.displayName, 'Anna');
    expect(controller.data.livePlace, 'Stockholm');
    expect(controller.step, OnboardingStep.location);
    expect(controller.revision, 4);
  });
  test('offline changes survive a controller restart and sync later', () async {
    final cache = MemoryDraftCache();
    final service = FakeDraftService(storage: DraftStorage())
      ..remote = const DraftSnapshot(1, 0, {'displayName': 'Old'});
    final first = await ProfileSetupController.load(service, cache: cache);
    first.data.displayName = 'Changed';
    first.changed(next: OnboardingStep.birthDate);
    service.offline = true;
    await expectLater(first.flush(), throwsA(isA<TimeoutException>()));
    first.dispose();
    final resumed = await ProfileSetupController.load(service, cache: cache);
    addTearDown(resumed.dispose);
    expect(resumed.data.displayName, 'Changed');
    expect(resumed.step, OnboardingStep.birthDate);
    expect(resumed.dirty, isTrue);
    service.offline = false;
    await resumed.flush();
    expect(service.remote!.data['displayName'], 'Changed');
    expect(cache.values['A']!['dirty'], isFalse);
  });
  test('a stale device cannot silently overwrite the other device draft',
      () async {
    final cache = MemoryDraftCache();
    await cache.write('A', {
      'revision': 1,
      'step': 0,
      'data': {'displayName': 'Local'},
      'dirty': true
    });
    final service = FakeDraftService(storage: DraftStorage())
      ..remote = const DraftSnapshot(2, 3, {'displayName': 'Other device'});
    await expectLater(
        ProfileSetupController.load(service, cache: cache),
        throwsA(isA<DraftException>()
            .having((e) => e.code, 'code', 'draft_conflict')));
    expect(cache.values['A']!['data']['displayName'], 'Local');
    final accepted = await ProfileSetupController.load(service,
        cache: cache, preferServer: true);
    addTearDown(accepted.dispose);
    expect(accepted.data.displayName, 'Other device');
    expect(accepted.dirty, isFalse);
  });
  test(
      'lost acknowledgement is reconciled instead of creating a false conflict',
      () async {
    final cache = MemoryDraftCache();
    final service = FakeDraftService(storage: DraftStorage());
    final first = await ProfileSetupController.load(service, cache: cache);
    first.data.displayName = 'Anna';
    first.changed();
    service.saving = (revision, step, data) async {
      service.remote = DraftSnapshot(1, step, data);
      throw TimeoutException('response lost');
    };
    await expectLater(first.flush(), throwsA(isA<TimeoutException>()));
    first.dispose();
    final resumed = await ProfileSetupController.load(service, cache: cache);
    addTearDown(resumed.dispose);
    expect(resumed.revision, 1);
    expect(resumed.dirty, isFalse);
    expect(resumed.data.displayName, 'Anna');
  });
  test('edits during an in-flight save use the acknowledged revision in order',
      () async {
    final cache = MemoryDraftCache();
    final service = FakeDraftService(storage: DraftStorage());
    final firstResult = Completer<DraftSnapshot>();
    final started = Completer<void>();
    service.saving = (revision, step, data) async {
      if (service.saves.length == 1) {
        started.complete();
        return firstResult.future;
      }
      return DraftSnapshot(revision + 1, step, data);
    };
    final controller = await ProfileSetupController.load(service, cache: cache);
    addTearDown(controller.dispose);
    controller.data.displayName = 'First';
    controller.changed();
    final saving = controller.flush();
    await started.future;
    controller.data.displayName = 'Second';
    controller.changed();
    firstResult.complete(const DraftSnapshot(1, 0, {'displayName': 'First'}));
    await saving;
    expect(service.saves.map((s) => s.revision), [0, 1]);
    expect(
        service.saves.map((s) => s.data['displayName']), ['First', 'Second']);
    expect(controller.dirty, isFalse);
    expect(cache.values['A']!['data']['displayName'], 'Second');
  });
  test('logout/account switch invalidates late draft responses', () async {
    final pending = Completer<DraftSnapshot>();
    final started = Completer<void>();
    final service = FakeDraftService(storage: DraftStorage());
    service.saving = (_, __, ___) {
      started.complete();
      return pending.future;
    };
    final controller =
        await ProfileSetupController.load(service, cache: MemoryDraftCache());
    addTearDown(controller.dispose);
    controller.data.displayName = 'A';
    controller.changed();
    final saving = controller.flush();
    final rejected =
        expectLater(saving, throwsA(isA<SessionChangedException>()));
    await started.future;
    AccountSession.reset();
    pending.complete(const DraftSnapshot(1, 0, {'displayName': 'A'}));
    await rejected;
  });
  test('another account never receives the previous account encrypted outbox',
      () async {
    final cache = MemoryDraftCache();
    await cache.write('A', {
      'revision': 0,
      'step': 8,
      'data': {'displayName': 'Private A'},
      'dirty': true
    });
    final controller = await ProfileSetupController.load(
        FakeDraftService(storage: DraftStorage('B')),
        cache: cache);
    addTearDown(controller.dispose);
    expect(controller.data.displayName, isEmpty);
    expect(controller.step, OnboardingStep.name);
  });
  test('expired photo rejection preserves answers and keeps still-valid photos',
      () async {
    final service = FakeDraftService(storage: DraftStorage());
    final controller =
        await ProfileSetupController.load(service, cache: MemoryDraftCache());
    addTearDown(controller.dispose);
    controller.data.displayName = 'Anna';
    controller.data.photoUrls = ['good', 'expired'];
    controller.changed();
    service.saving = (_, __, ___) async => throw const DraftException(
        'Bilden har gått ut.',
        code: 'draft_photo_expired',
        validPhotos: ['good']);
    await expectLater(controller.flush(), throwsA(isA<DraftException>()));
    expect(controller.data.displayName, 'Anna');
    expect(controller.data.photoUrls, ['good']);
    expect(controller.photosExpired, isTrue);
    service.saving = null;
    await controller.flush();
    expect(controller.dirty, isFalse);
  });
  for (final code in ['session_expired', 'profile_exists']) {
    test('cached answers do not hide server state: $code', () async {
      final cache = MemoryDraftCache();
      await cache.write('A', {
        'revision': 1,
        'step': 2,
        'data': {'displayName': 'Local'},
        'dirty': true
      });
      final service = FakeDraftService(storage: DraftStorage())
        ..loadFailure = DraftException('Server state', code: code);
      await expectLater(ProfileSetupController.load(service, cache: cache),
          throwsA(isA<DraftException>().having((e) => e.code, 'code', code)));
      expect(cache.values['A']!['data']['displayName'], 'Local');
    });
  }
  test('successful completion removes local pending data', () async {
    final cache = MemoryDraftCache();
    final controller = await ProfileSetupController.load(
        FakeDraftService(storage: DraftStorage()),
        cache: cache);
    addTearDown(controller.dispose);
    controller.data.displayName = 'Anna';
    controller.changed();
    await controller.flush();
    await controller.completed();
    expect(cache.values.containsKey('A'), isFalse);
  });
  test('real cache uses secure storage and serializes replacement/removal',
      () async {
    final cache = DraftCache();
    await cache.write('A', {
      'revision': 1,
      'step': 0,
      'data': {'displayName': 'Private'},
      'dirty': true
    });
    expect((await cache.read('A'))!['data']['displayName'], 'Private');
    expect(await cache.read('B'), isNull);
    await Future.wait([
      cache.write('A', {'revision': 2, 'step': 1, 'data': {}, 'dirty': false}),
      cache.clear('A')
    ]);
    expect(await cache.read('A'), isNull);
  });
  test('all answer fields round-trip without inventing optional values', () {
    final data = OnboardingData()
      ..displayName = 'Anna'
      ..birthDate = DateTime(1998, 5, 2)
      ..gender = 'Kvinna'
      ..distanceKm = 80
      ..heightCm = 170
      ..studyPlace = 'University'
      ..photoUrls = ['https://example.test/a'];
    expect(OnboardingData.fromDraft(data.toDraft()).toDraft(), data.toDraft());
    expect(OnboardingData.fromDraft({}).heightCm, isNull);
    expect(OnboardingData.fromDraft({}).religion, isEmpty);
  });
}
