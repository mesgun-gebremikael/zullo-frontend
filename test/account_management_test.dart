import 'dart:async';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/session_http_client.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/account_management_page.dart';
import 'package:zullo_app/services/account_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/swipe_page.dart';

class ImmediateAccountStorage extends AuthStorage {
  @override
  Future<String?> getToken() async => 'test-token';
}

class FakeAccountService extends AccountService {
  bool value = false;
  int changes = 0, removals = 0;
  @override
  Future<bool> paused() async => value;
  @override
  Future<bool> pause(bool next) async {
    changes++;
    return value = next;
  }

  @override
  Future<Map<String, dynamic>> remove(String password) async {
    removals++;
    throw const AccountException(
        400, 'Lösenordet stämmer inte. Kontot har inte ändrats.');
  }
}

void main() {
  test(
      'removal sends explicit confirmation and accepts asynchronous erasure follow-up',
      () async {
    final service = AccountService(
        storage: ImmediateAccountStorage(),
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/me/account/removal');
          expect(jsonDecode(request.body),
              {'password': 'test-password', 'confirm': true});
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response(
              '{"requestId":"request","cleanupPending":true}', 202);
        }));
    expect((await service.remove('test-password'))['cleanupPending'], isTrue);
  });
  test(
      'authenticated expiry is coalesced and an old response cannot invalidate the next account',
      () async {
    final events = <void>[];
    final sub = AccountSession.expiredStream.listen(events.add);
    final old = AccountSession.generation;
    final pending = Completer<http.Response>();
    final client = SessionHttpClient(MockClient((_) => pending.future),
        generation: () => old);
    final request = client.get(
        Uri.parse('https://example.test/me/account/status'),
        headers: {'Authorization': 'Bearer old'});
    final rejected =
        expectLater(request, throwsA(isA<SessionChangedException>()));
    AccountSession.reset();
    pending.complete(http.Response('{}', 401));
    await rejected;
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    final current =
        SessionHttpClient(MockClient((_) async => http.Response('{}', 401)));
    for (var i = 0; i < 2; i++) {
      await current.get(Uri.parse('https://example.test/me/account/status'),
          headers: {'Authorization': 'Bearer current'});
    }
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 1);
    await sub.cancel();
  });

  testWidgets('pause and reactivate reflect confirmed account state',
      (tester) async {
    final service = FakeAccountService();
    await tester
        .pumpWidget(MaterialApp(home: AccountManagementPage(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Pausa konto'));
    await tester.pumpAndSettle();
    expect(find.text('Ditt konto är pausat'), findsOneWidget);
    await tester.tap(find.text('Återaktivera konto'));
    await tester.pumpAndSettle();
    expect(service.changes, 2);
    expect(service.value, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'removal requires password and explicit confirmation; a rejection keeps account screen',
      (tester) async {
    final service = FakeAccountService();
    await tester
        .pumpWidget(MaterialApp(home: AccountRemovalPage(service: service)));
    await tester.pumpAndSettle();
    final button =
        find.widgetWithText(FilledButton, 'Stäng konto och begär radering');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'wrong-password');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(service.removals, 1);
    expect(find.text('Lösenordet stämmer inte. Kontot har inte ändrats.'),
        findsOneWidget);
    expect(find.byType(AccountRemovalPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'compact swipe screen has only real actions and no placeholder modes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final drag = ValueNotifier(Offset.zero);
    addTearDown(drag.dispose);
    var undo = 0, edit = 0, likes = 0;
    await tester.pumpWidget(MaterialApp(
        home: SwipePage(
            isLoading: false,
            hasActiveProfile: true,
            hasUnreadMessages: false,
            dragListenable: drag,
            nextCard: null,
            activeCard: const ColoredBox(color: Colors.grey),
            emptyState: const SizedBox(),
            onOpenRadiusSheet: () {},
            onOpenMatchesPage: () {},
            onLogout: () {},
            onOpenEditProfile: () => edit++,
            onSwipeLeft: () {},
            onSwipeUp: () {},
            onSwipeRight: () => likes++,
            onRewind: () => undo++)));
    expect(find.text('Duos'), findsNothing);
    expect(find.text('Astro'), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    await tester.tap(find.byTooltip('Ångra senaste swipe'));
    await tester.tap(find.byTooltip('Redigera profil'));
    await tester.tap(find.byTooltip('Gilla'));
    expect([undo, edit, likes], [1, 1, 1]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
