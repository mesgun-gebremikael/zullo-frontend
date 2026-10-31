import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/home_page.dart';
import 'package:zullo_app/main_navigation.dart';
import 'package:zullo_app/models/swipe_profile.dart';
import 'package:zullo_app/register_page.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/signalr_service.dart';
import 'package:zullo_app/welcome_page.dart';
import 'support/fake_chat_transport.dart';

class SlowLogoutAuth extends AuthService {
  final finishLogout = Completer<void>();
  @override
  Future<void> logout() async {
    await AuthStorage().clearAuth();
    await finishLogout.future;
  }
  @override
  Future<Map<String, dynamic>> getSwipeFeed({int minAge = 18, int maxAge = 99}) async =>
    {'profiles': <SwipeProfile>[], 'radiusKm': 50.0};
  @override
  Future<Map<String, dynamic>> getMyProfile() async => {'photoUrls': []};
  @override
  Future<List<dynamic>> getMatches() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('logout reaches welcome after its tab is disposed, then registration opens', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() async {
      await AuthStorage().clearAuth();
      await AuthStorage().saveAuth(token: 'token', userId: 'A');
    });
    final auth = SlowLogoutAuth();
    await tester.pumpWidget(MaterialApp(home: MainNavigation(
      authService: auth, liveService: SignalRService(transport: FakeChatTransport()),
      pages: [HomePage(authService: auth), const SizedBox(), const SizedBox(),
        const SizedBox(), const SizedBox()])));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.logout));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    expect(find.byType(HomePage), findsNothing);
    await tester.runAsync(() async {
      expect(await AuthStorage().getToken(), isNull);
      auth.finishLogout.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.byType(MainNavigation), findsNothing);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
