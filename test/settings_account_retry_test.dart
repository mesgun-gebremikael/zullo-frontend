import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/account_management_page.dart';
import 'package:zullo_app/blocked_profiles_page.dart';
import 'package:zullo_app/services/account_service.dart';
import 'package:zullo_app/services/block_service.dart';

class RetryAccount extends AccountService {
  int calls = 0;
  final pending = Completer<bool>();
  @override
  Future<bool> paused() {
    calls++;
    return calls == 1 ? Future.error(StateError('offline')) : pending.future;
  }
}

class PendingPause extends AccountService {
  int changes = 0;
  final pending = Completer<bool>();
  @override
  Future<bool> paused() async => false;
  @override
  Future<bool> pause(bool value) {
    changes++;
    return pending.future;
  }
}

class ConfirmBlock extends BlockService {
  int removals = 0;
  @override
  Future<List<Map<String, dynamic>>> getBlockedUsers() async => [
        {'userId': 'peer', 'displayName': 'Anna'}
      ];
  @override
  Future<void> unblockUser(String id) async {
    removals++;
  }
}

class BlockStorage extends AuthStorage {
  @override
  Future<String?> getToken() async => 'token';
}

void main() {
  for (final response in ['{}', '{"paused":"false"}', '{"paused":null}']) {
    test('malformed account state cannot be presented as active: $response',
        () async {
      final service = AccountService(
          storage: BlockStorage(),
          client: MockClient((_) async => http.Response(response, 200)));
      await expectLater(service.paused(), throwsA(isA<AccountException>()));
      await expectLater(service.pause(true), throwsA(isA<AccountException>()));
    });
  }
  test('blocked-list authentication expiry reaches the shared session handler',
      () async {
    final events = <void>[];
    final sub = AccountSession.expiredStream.listen(events.add);
    addTearDown(sub.cancel);
    AccountSession.reset();
    final service = BlockService(
        storage: BlockStorage(),
        client: MockClient((_) async => http.Response('{}', 401)));
    await expectLater(service.getBlockedUsers(), throwsException);
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 1);
  });
  test(
      'delayed blocked list from an old account is rejected without expiring the new account',
      () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final service = BlockService(
        storage: BlockStorage(),
        client: MockClient((_) {
          started.complete();
          return response.future;
        }));
    final result = service.getBlockedUsers();
    final rejected =
        expectLater(result, throwsA(isA<SessionChangedException>()));
    await started.future;
    AccountSession.reset();
    response.complete(http.Response('[]', 200));
    await rejected;
  });
  testWidgets('pause coalesces rapid taps and preserves prior state on failure',
      (tester) async {
    final service = PendingPause();
    await tester
        .pumpWidget(MaterialApp(home: AccountManagementPage(service: service)));
    await tester.pumpAndSettle();
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Pausa konto'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(service.changes, 1);
    expect(find.text('Ditt konto är pausat'), findsNothing);
    service.pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Kunde inte bekräfta ändringen. Försök igen.'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Pausa konto'))
            .onPressed,
        isNotNull);
  });
  testWidgets(
      'account retry clears error and shows progress until confirmed state',
      (tester) async {
    final service = RetryAccount();
    await tester
        .pumpWidget(MaterialApp(home: AccountManagementPage(service: service)));
    await tester.pumpAndSettle();
    expect(
        find.text('Kunde inte läsa kontostatus. Försök igen.'), findsOneWidget);
    await tester.tap(find.text('Försök igen'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        find.text('Kunde inte läsa kontostatus. Försök igen.'), findsNothing);
    expect(service.calls, 2);
    service.pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Ditt konto är pausat'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets(
      'unblock reserves its row before dialog and cancellation releases it',
      (tester) async {
    final service = ConfirmBlock();
    await tester
        .pumpWidget(MaterialApp(home: BlockedProfilesPage(service: service)));
    await tester.pumpAndSettle();
    final button = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Avblockera'));
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();
    expect(service.removals, 0);
    await tester.tap(find.text('Avblockera'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Avblockera').last);
    await tester.pumpAndSettle();
    expect(service.removals, 1);
    expect(find.text('Du har inga blockerade profiler.'), findsOneWidget);
  });
}
