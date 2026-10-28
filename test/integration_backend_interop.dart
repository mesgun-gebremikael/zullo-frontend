// Run explicitly against verify-flutter-interop.sh's disposable backend.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/services/api_config.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/messages_service.dart';
import 'package:zullo_app/services/signalr_service.dart';
import 'package:zullo_app/services/thread_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Flutter client interoperates with real HTTP, SignalR and PostgreSQL',
      () async {
    final path = Platform.environment['ZULLO_INTEROP_FIXTURE'];
    expect(path, isNotNull,
        reason: 'Use the disposable backend interop script.');
    final fixture =
        jsonDecode(File(path!).readAsStringSync()) as Map<String, dynamic>;
    HttpOverrides.global =
        null; // This explicit integration test needs real loopback I/O.
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final storage = AuthStorage();
    await storage.clearAuth();
    await storage.saveAuth(token: fixture['tokenA'], userId: fixture['a']);
    final service = MessagesService(ApiConfig.baseUrl, storage);
    final live = SignalRService();
    final httpClient = http.Client();
    addTearDown(() async {
      await live.dispose();
      httpClient.close();
      await storage.clearAuth();
    });
    final b = fixture['b'] as String;
    final headersB = {
      'Authorization': 'Bearer ${fixture['tokenB']}',
      'Content-Type': 'application/json'
    };
    final matches = await AuthService().getMatches();
    expect(matches.any((row) => row['userId'] == b), isTrue);
    await live.connect();
    final event =
        live.messagesStream.first.timeout(const Duration(seconds: 10));
    final history = ThreadHistory(service, b);
    expect(await history.synchronize(), isEmpty);
    final sent = await service.sendMessage(
        toUserId: b,
        text: 'Interop message',
        clientMessageId: 'interop-stable');
    expect((await event)['id'], sent['id']);
    final replay = await service.sendMessage(
        toUserId: b,
        text: 'Interop message',
        clientMessageId: 'interop-stable');
    expect(replay['id'], sent['id']);
    final readEvent =
        live.messagesReadStream.first.timeout(const Duration(seconds: 10));
    final read = await httpClient.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/messages/mark-read?otherUserId=${fixture['a']}'),
        headers: headersB);
    expect(read.statusCode, 200);
    expect((await readEvent)['readThroughSequence'], sent['sequence']);
    await history.synchronize();
    expect(history.rows.length, 1);
    expect(history.outgoingReadThrough, sent['sequence']);
    await live.disconnect();
    final missed =
        await httpClient.post(Uri.parse('${ApiConfig.baseUrl}/messages/send'),
            headers: headersB,
            body: jsonEncode({
              'toUserId': fixture['a'],
              'text': 'Sent while disconnected',
              'clientMessageId': 'interop-offline'
            }));
    expect(missed.statusCode, 200);
    await live.connect();
    await history.synchronize();
    expect(history.rows.map((m) => m['text']),
        contains('Sent while disconnected'));
    expect(history.rows.length, 2);
    await expectLater(
        service.getThreadPage(fixture['c']),
        throwsA(isA<ChatRequestException>()
            .having((e) => e.statusCode, 'status', 403)));
    final blocked = await httpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/blocks'),
        headers: headersB,
        body: jsonEncode({'blockedUserId': fixture['a']}));
    expect(blocked.statusCode, 200);
    await expectLater(
        service.getThreadPage(b),
        throwsA(isA<ChatRequestException>()
            .having((e) => e.statusCode, 'status', 403)));
    await expectLater(
        service.sendMessage(
            toUserId: b,
            text: 'Interop message',
            clientMessageId: 'interop-stable'),
        throwsA(isA<ChatRequestException>()
            .having((e) => e.statusCode, 'status', 403)));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
