import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/matches_page.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/matches_cache_service.dart';

void main() {
  testWidgets(
      'account switch hides the previous account match screen and cache',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage();
    await storage.saveAuth(token: 'A', userId: 'A');
    MatchesCacheService.setData(matches: [
      {
        'userId': 'peer',
        'displayName': 'Private name A',
        'age': 25,
        'photoUrl': '',
        'lastMessageText': '',
        'unreadMessageCount': 0
      }
    ], likesReceived: []);
    final auth =
        AuthService(client: MockClient((_) async => http.Response('[]', 200)));
    await tester.pumpWidget(MaterialApp(home: MatchesPage(authService: auth)));
    // The cached profile is rendered before any network response.
    expect(find.text('Private name A'), findsWidgets);
    await storage.clearAuth();
    await tester.pump();
    expect(find.text('Private name A'), findsNothing);
    await storage.saveAuth(token: 'B', userId: 'B');
    final b =
        AuthService(client: MockClient((_) async => http.Response('[]', 200)));
    await tester.pumpWidget(MaterialApp(
        home: MatchesPage(key: const ValueKey('B'), authService: b)));
    await tester.pumpAndSettle();
    expect(find.text('Private name A'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
