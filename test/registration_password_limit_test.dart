import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/l10n/app_localizations.dart';
import 'package:zullo_app/register_page.dart';
import 'package:zullo_app/services/auth_service.dart';

class _Registration extends AuthService {
  int calls = 0;
  final pending = Completer<void>();
  @override
  Future<void> registerAndLogin(
      {required String email, required String password, String? name}) {
    calls++;
    return pending.future;
  }
}

void main() {
  for (final boundary in <String, String>{
    'ASCII': 'a' * 72,
    'Swedish': 'å' * 36,
    'emoji': '😀' * 18,
  }.entries) {
    for (final tooLong in [false, true]) {
      testWidgets('${boundary.key} byte boundary: too long $tooLong',
          (tester) async {
        final auth = _Registration();
        await tester
            .pumpWidget(MaterialApp(home: RegisterPage(authService: auth)));
        await tester.enterText(
            find.byType(TextField).at(0), 'person@example.com');
        await tester.enterText(find.byType(TextField).at(1),
            boundary.value + (tooLong ? 'a' : ''));
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        expect(auth.calls, tooLong ? 0 : 1);
        expect(find.text('Välj ett kortare lösenord.'),
            tooLong ? findsOneWidget : findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final locale in ['en', 'de', 'nl', 'ar']) {
    testWidgets('registration length error localized in $locale',
        (tester) async {
      final auth = _Registration();
      await tester.pumpWidget(MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RegisterPage(authService: auth),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).at(0), 'person@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'å' * 37);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      final context = tester.element(find.byType(RegisterPage));
      expect(find.text(AppLocalizations.of(context).chooseShorterPassword),
          findsOneWidget);
      expect(Directionality.of(context),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      expect(auth.calls, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
