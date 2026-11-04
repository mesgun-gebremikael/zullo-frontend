import 'package:zullo_app/services/messages_service.dart';
import 'package:zullo_app/services/chat_thread_cache_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/blocked_profiles_page.dart';
import 'package:zullo_app/profile_settings_page.dart';
import 'package:zullo_app/home_page.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/block_service.dart';
import 'package:zullo_app/services/chat_repository.dart';
import 'package:zullo_app/services/relation_changes.dart';
import 'package:zullo_app/models/chat_list_item.dart';
import 'package:zullo_app/models/swipe_profile.dart';

class TestStorage extends AuthStorage {
  @override
  Future<String?> getToken() async => 'token';
}

class SettingsAuth extends AuthService {
  @override
  Future<Map<String, dynamic>> discoverySettings(
      {Map<String, dynamic>? update}) async {
    if (update?['interestedIn'] is String) preference = update!['interestedIn'];
    if (update?['radiusKm'] is int) savedRadius = update!['radiusKm'];
    return {'minAge': 18, 'maxAge': 99};
  }

  String preference = 'Kvinnor';
  int? savedRadius;
  final feedPreferences = <String>[];
  @override
  Future<Map<String, dynamic>> getMyAccount() async =>
      {'email': 'owner@example.test'};
  @override
  Future<Map<String, dynamic>> getMyProfile() async => {
        'matchRadiusKm': 153,
        'photoUrls': [],
        'interestedIn': preference,
        'intention': '',
        'religion': ''
      };
  @override
  Future<List<dynamic>> getMatches() async => [];
  @override
  Future<Map<String, dynamic>> getSwipeFeed(
      {int minAge = 18, int maxAge = 99}) async {
    feedPreferences.add(preference);
    return {'profiles': <SwipeProfile>[], 'radiusKm': 50.0};
  }

  @override
  Future<void> updateFilterProfile(
      {required String intention,
      required String religion,
      int? matchRadiusKm,
      String? interestedIn}) async {
    preference = interestedIn!;
    savedRadius = matchRadiusKm;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().clearAuth();
  });

  testWidgets('account shows its email and opens blocked profiles',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: ProfileSettingsPage(authService: SettingsAuth())));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('owner@example.test'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Blockerade profiler'), 300);
    expect(find.text('Blockerade profiler'), findsOneWidget);
  });

  testWidgets(
      'blocked profiles load from server and unblock only after confirmation',
      (tester) async {
    final paths = <String>[];
    final service = BlockService(
        storage: TestStorage(),
        client: MockClient((request) async {
          paths.add('${request.method} ${request.url.path}');
          return request.method == 'GET'
              ? http.Response('[{"userId":"other","displayName":"Anna"}]', 200)
              : http.Response('', 204);
        }));
    await tester
        .pumpWidget(MaterialApp(home: BlockedProfilesPage(service: service)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    await tester.tap(find.text('Avblockera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();
    expect(paths, ['GET /blocks']);
    await tester.tap(find.text('Avblockera'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Avblockera').last);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(paths, ['GET /blocks', 'DELETE /blocks/other']);
    expect(find.text('Du har inga blockerade profiler.'), findsOneWidget);
  });

  testWidgets('discovery preference is editable and reloads feed after saving',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = SettingsAuth();
    await tester.pumpWidget(MaterialApp(home: HomePage(authService: auth)));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Ändra filter'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intresserad av'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Män').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Spara inställningar'));
    await tester.tap(find.text('Spara inställningar'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(auth.preference, 'Män');
    expect(auth.savedRadius, 153);
    expect(auth.feedPreferences.last, 'Män');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('filter request persists discovery preference without unrelated fields',
      () async {
    final auth = AuthService(client: MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(jsonDecode(request.body)['interestedIn'], 'Män');
      expect(jsonDecode(request.body).containsKey('displayName'), isFalse);
      return http.Response('{}', 200);
    }));
    await auth.updateFilterProfile(
        intention: '', religion: '', interestedIn: 'Män');
  });

  for (final samePeer in [true, false]) {
    test(
        'in-flight history invalidation is scoped to its conversation ($samePeer)',
        () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final service =
          MessagesService('http://test', AuthStorage(), client: MockClient((_) {
        started.complete();
        return response.future;
      }));
      final pending = service.getThreadPage('peer');
      final expectation = expectLater(
          pending, samePeer ? throwsA(isA<ChatRequestException>()) : completes);
      await started.future;
      RelationChanges.notify(samePeer ? 'peer' : 'unrelated');
      response.complete(http.Response('{"messages":[],"hasMore":false}', 200));
      await expectation;
    });
  }

  test(
      'a rematch after missed live events discards the old cached conversation',
      () {
    ChatListItem match(String created) => ChatListItem.fromJson({
          'userId': 'other',
          'displayName': 'Anna',
          'matchCreatedAtUtc': created,
        });
    ChatRepository.instance.setChatList([match('2026-10-01T00:00:00Z')]);
    ChatThreadCacheService.setThread('other', [
      {'text': 'old conversation'}
    ]);
    ChatRepository.instance.setChatList([match('2026-11-01T00:00:00Z')]);
    expect(ChatThreadCacheService.getThread('other'), isNull);
    expect(ChatRepository.instance.chatList.single.userId, 'other');
    ChatThreadCacheService.setThread('other', [
      {'text': 'new conversation'}
    ]);
    ChatRepository.instance.setChatList([match('2026-11-01T00:00:00Z')]);
    expect(ChatThreadCacheService.getThread('other')!.single['text'],
        'new conversation');
    ChatRepository.instance.setChatList([]);
    expect(ChatThreadCacheService.getThread('other'), isNull);
  });

  test(
      'relationship invalidation removes cached chat immediately and rejects stale list',
      () async {
    ChatRepository.instance.setChatList([
      const ChatListItem(
          userId: 'other',
          displayName: 'Anna',
          age: 25,
          photoUrl: '',
          lastMessageText: 'old',
          lastMessageAtUtc: null,
          hasUnread: true,
          unreadMessageCount: 1)
    ]);
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final auth = AuthService(client: MockClient((_) {
      started.complete();
      return response.future;
    }));
    final pending = auth.getMatches();
    final rejected = expectLater(pending, throwsStateError);
    await started.future;
    RelationChanges.notify('other');
    expect(ChatRepository.instance.chatList, isEmpty);
    response.complete(http.Response('[{"userId":"other"}]', 200));
    await rejected;
  });
}
