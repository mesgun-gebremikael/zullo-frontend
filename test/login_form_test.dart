import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/login_page.dart';
import 'package:zullo_app/services/auth_service.dart';

class ControlledLogin extends AuthService {
  int calls = 0;
  String? password;
  final result = Completer<void>();
  @override
  Future<void> login({required String email, required String password}) {
    calls++;
    this.password = password;
    return result.future;
  }
}

void main() {
  testWidgets(
      'login preserves password spaces and repeated taps send one request',
      (tester) async {
    final auth = ControlledLogin();
    await tester.pumpWidget(MaterialApp(home: LoginPage(authService: auth)));
    await tester.enterText(
        find.byType(TextFormField).at(0), 'person@example.test');
    await tester.enterText(
        find.byType(TextFormField).at(1), '  valid password  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Logga in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Logga in'));
    await tester.pump();
    expect(auth.calls, 1);
    expect(auth.password, '  valid password  ');
    auth.result.completeError(AuthRequestException('Kontrollera uppgifterna.'));
    await tester.pumpAndSettle();
    expect(find.text('Kontrollera uppgifterna.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
