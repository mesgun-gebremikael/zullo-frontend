import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/likes_page.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/matches_refresh_service.dart';
import 'package:zullo_app/widgets/discovery_settings_sheet.dart';

class ImmediateStorage extends AuthStorage {
  @override
  Future<String?> getToken() async => 'A';
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AuthStorage().saveAuth(token: 'A', userId: 'A');
  });
  testWidgets(
      'locked incoming like is counted and never renders chat or identity; live refresh clears it',
      (tester) async {
    var count = 1, chats = 0;
    final auth = AuthService(
        storage: ImmediateStorage(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/summary')) {
            return http.Response(
                '{"totalCount":$count,"hiddenCount":$count,"canViewAll":false}',
                200);
          }
          if (request.url.path.endsWith('/likes/received')) {
            return http.Response('[]', 200);
          }
          chats++;
          return http.Response('[]', 200);
        }));
    await tester.pumpWidget(MaterialApp(home: LikesPage(authService: auth)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('1 like'), findsOneWidget);
    expect(
        find.bySemanticsLabel('Dold like. Visa med Premium'), findsOneWidget);
    expect(find.text('Inga nya likes än'), findsNothing);
    expect(find.text('Chattar'), findsNothing);
    expect(chats, 0);
    count = 0;
    MatchesRefreshService.instance.requestRefresh();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('0 likes'), findsOneWidget);
    expect(find.bySemanticsLabel('Dold like. Visa med Premium'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('failed summary never claims there are no likes', (tester) async {
    final auth = AuthService(
        storage: ImmediateStorage(),
        client: MockClient((request) async => http.Response(
            request.url.path.endsWith('/summary') ? '{}' : '[]',
            request.url.path.endsWith('/summary') ? 503 : 200)));
    await tester.pumpWidget(MaterialApp(home: LikesPage(authService: auth)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(
        find.text('Kunde inte hämta dina likes. Försök igen.'), findsOneWidget);
    expect(find.text('0 likes'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'visible Superlike appears only in Likes and stale identities disappear on logout',
      (tester) async {
    final auth = AuthService(
        storage: ImmediateStorage(),
        client: MockClient((request) async => http.Response(
            request.url.path.endsWith('/summary')
                ? '{"totalCount":1,"hiddenCount":0,"canViewAll":false}'
                : '[{"userId":"sender","displayName":"Visible sender","age":25,"photoUrl":"","isSuperLike":true}]',
            200)));
    await tester.pumpWidget(MaterialApp(home: LikesPage(authService: auth)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('Visible sender, 25'), findsOneWidget);
    expect(find.text('Har supergillat dig'), findsOneWidget);
    await tester.runAsync(() => AuthStorage().clearAuth());
    await tester.pump();
    expect(find.text('Visible sender, 25'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'modern interest picker saves chosen value once and stays open on save failure',
      (tester) async {
    DiscoveryPreferences? saved;
    final pending = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => DiscoverySettingsSheet(
                              initial: const DiscoveryPreferences(
                                  interestedIn: 'Kvinnor',
                                  radiusKm: 153,
                                  minAge: 18,
                                  maxAge: 99),
                              onSave: (value) async {
                                saved = value;
                                await pending.future;
                              },
                            )),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intresserad av'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Män'));
    await tester.tap(find.text('Män'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    final save = find.text('Spara inställningar');
    await tester.scrollUntilVisible(save, 200,
        scrollable: find
            .descendant(
                of: find.byType(DiscoverySettingsSheet),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(save);
    await tester.pump();
    expect(saved!.interestedIn, 'Män');
    expect(saved!.radiusKm, 153);
    expect(find.text('Sparar…'), findsOneWidget);
    pending.completeError(StateError('offline'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Kunde inte spara.'), findsOneWidget);
    expect(find.text('Spara inställningar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
