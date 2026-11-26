import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/push_installation_binding.dart';

class RecordStore implements PushInstallationRecordStore {
  String? value;
  bool failRead = false, failWrite = false;
  Completer<void>? nextWrite;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('Keystore unavailable');
    return value;
  }

  @override
  Future<void> write(String record) async {
    final pending = nextWrite;
    nextWrite = null;
    if (pending != null) await pending.future;
    if (failWrite) throw StateError('Keystore write failed');
    value = record;
  }
}

class _ObservedAuthStorage extends AuthStorage {
  final read = Completer<String?>();
  @override
  Future<String?> getToken() async {
    final token = await super.getToken();
    if (!read.isCompleted) read.complete(token);
    return token;
  }
}

class _BlockedAuthStorage extends AuthStorage {
  final token = Completer<String?>();
  @override
  Future<String?> getToken() => token.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AuthStorage().clearAuth();
    await AuthStorage().saveAuth(token: 'A-token', userId: 'A');
  });

  test('identity and strictly increasing reservations survive service restarts',
      () async {
    final store = RecordStore();
    final first = await PushInstallationBinding(store: store).reserve();
    final second = await PushInstallationBinding(store: store).reserve();
    expect(
        first.installationId,
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(second.installationId, first.installationId);
    expect([first.version, second.version], [1, 2]);
  });

  test('queued reservation intents cannot overtake a slow earlier write',
      () async {
    final blocked = Completer<void>();
    final store = RecordStore()..nextWrite = blocked;
    final a = PushInstallationBinding(store: store).reserve();
    var bFinished = false;
    final b = PushInstallationBinding(store: store).reserve().then((v) {
      bFinished = true;
      return v;
    });
    await Future<void>.delayed(Duration.zero);
    expect(bFinished, isFalse);
    blocked.complete();
    expect((await a).version, 1);
    expect((await b).version, 2);
  });

  for (final value in [
    '{}',
    '{"installationId":"broken","version":1}',
    '{"installationId":"00000000-0000-4000-8000-000000000000","version":"1"}'
  ]) {
    test(
        'corrupt metadata fails closed without regenerating/reusing versions: $value',
        () async {
      final store = RecordStore()..value = value;
      await expectLater(
          PushInstallationBinding(store: store).reserve(), throwsA(anything));
      expect(store.value, value);
    });
  }

  test(
      'read or write failure sends no versionless request and logout remains local',
      () async {
    for (final reading in [true, false]) {
      final store = RecordStore()
        ..failRead = reading
        ..failWrite = !reading;
      var requests = 0;
      final auth = AuthService(
          pushInstallation: PushInstallationBinding(store: store),
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }));
      await expectLater(auth.saveDeviceToken('FCM'), throwsStateError);
      await auth.logout();
      await Future<void>.delayed(Duration.zero);
      expect(requests, 0);
      expect(await AuthStorage().getToken(), isNull);
      await AuthStorage().saveAuth(token: 'A-token', userId: 'A');
    }
  });

  for (final token in <String?>['A-token', null]) {
    test(
        'push reservation failure is observed while logout token read waits: $token',
        () async {
      final store = RecordStore()..failRead = true;
      final storage = _BlockedAuthStorage();
      var requests = 0;
      final auth = AuthService(
        storage: storage,
        pushInstallation: PushInstallationBinding(store: store),
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      var finished = false;
      final logout = auth.logout().then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      expect(requests, 0);
      storage.token.complete(token);
      await logout;
      await Future<void>.delayed(Duration.zero);
      expect(requests, 0);
      expect(await AuthStorage().getToken(), isNull);
    });
  }

  test(
      'push reservation failure remains guarded before delayed token lookup completes',
      () async {
    final store = RecordStore()..failRead = true;
    final storage = _BlockedAuthStorage();
    var requests = 0;
    final auth = AuthService(
      storage: storage,
      pushInstallation: PushInstallationBinding(store: store),
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    final registration = auth.saveDeviceToken('FCM');
    final rejected = expectLater(registration, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 0);
    storage.token.complete('A-token');
    await rejected;
    expect(requests, 0);
    expect(await AuthStorage().getToken(), 'A-token');
  });

  test('in-flight A registration arrives after B with an older intent version',
      () async {
    final store = RecordStore();
    final aArrived = Completer<void>(), releaseA = Completer<void>();
    final sent = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.headers['Authorization'] == 'Bearer A-token') {
        aArrived.complete();
        await releaseA.future;
      }
      sent.add(data);
      return http.Response('{}', 200);
    });
    final a = AuthService(
        pushInstallation: PushInstallationBinding(store: store),
        client: client);
    final old = a.saveDeviceToken('same-FCM');
    final stale = expectLater(old, throwsA(isA<SessionChangedException>()));
    await aArrived.future;
    await AuthStorage().saveAuth(token: 'B-token', userId: 'B');
    await AuthService(
            pushInstallation: PushInstallationBinding(store: store),
            client: client)
        .saveDeviceToken('same-FCM');
    releaseA.complete();
    await stale;
    expect(sent.map((m) => m['version']), [2, 1]);
    expect(sent[0]['installationId'], sent[1]['installationId']);
  });

  test(
      'old logout reserves before B claim even when unlink persistence is delayed',
      () async {
    final block = Completer<void>();
    final store = RecordStore()..nextWrite = block;
    final requests = <(String, Map<String, dynamic>)>[];
    final client = MockClient((request) async {
      requests.add(
          (request.url.path, jsonDecode(request.body) as Map<String, dynamic>));
      return http.Response('{}', 200);
    });
    final a = AuthService(
        pushInstallation: PushInstallationBinding(store: store),
        client: client);
    await a.logout();
    expect(await AuthStorage().getToken(), isNull);
    await AuthStorage().saveAuth(token: 'B-token', userId: 'B');
    final b = AuthService(
            pushInstallation: PushInstallationBinding(store: store),
            client: client)
        .saveDeviceToken('FCM');
    await Future<void>.delayed(Duration.zero);
    expect(requests, isEmpty);
    block.complete();
    await b;
    await Future<void>.delayed(Duration.zero);
    final clear = requests.singleWhere((r) => r.$1.endsWith('/clear')).$2;
    final claim = requests.singleWhere((r) => !r.$1.endsWith('/clear')).$2;
    expect(clear['version'], 1);
    expect(claim['version'], 2);
    expect(clear['installationId'], claim['installationId']);
    expect(await AuthStorage().getUserId(), 'B');
  });

  test('reusing an AuthService for B cannot revive a stalled A claim',
      () async {
    final block = Completer<void>();
    final store = RecordStore()..nextWrite = block;
    final storage = _ObservedAuthStorage();
    var claims = 0;
    final auth = AuthService(
      storage: storage,
      pushInstallation: PushInstallationBinding(store: store),
      pushTokenLoader: () async => null,
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response('{"token":"B-token","userId":"B"}', 200);
        }
        claims++;
        return http.Response('{}', 200);
      }),
    );
    final old = auth.saveDeviceToken('FCM');
    final rejected = expectLater(old, throwsA(isA<SessionChangedException>()));
    expect(await storage.read.future, 'A-token');
    await auth.login(email: 'b@example.test', password: 'password123');
    block.complete();
    await rejected;
    expect(claims, 0);
    expect(await AuthStorage().getUserId(), 'B');
  });

  test('the default encrypted installation record survives auth removal',
      () async {
    final first = await PushInstallationBinding().reserve();
    await AuthStorage().clearAuth();
    final afterLogout = await PushInstallationBinding().reserve();
    expect(afterLogout.installationId, first.installationId);
    expect(afterLogout.version, first.version + 1);
  });
}
