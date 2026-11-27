import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/l10n/app_localizations.dart';
import 'package:zullo_app/l10n/language_settings_page.dart';
import 'package:zullo_app/l10n/locale_catalog.dart';
import 'package:zullo_app/l10n/locale_controller.dart';

Widget _app(LocaleController controller) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        locale: controller.locale,
        supportedLocales: LocaleCatalog.supported,
        localeListResolutionCallback: LocaleCatalog.resolve,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: LanguageSettingsPage(controller: controller),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('German, Dutch and automatic settings save and update the UI',
      (tester) async {
    final controller = LocaleController();
    await controller.load();
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const ValueKey('language-de')));
    await tester.pumpAndSettle();
    expect(controller.locale, const Locale('de'));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('language-nl')), 200);
    await tester.tap(find.byKey(const ValueKey('language-nl')));
    await tester.pumpAndSettle();
    expect(controller.locale, const Locale('nl'));
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(controller.locale, isNull);
    expect(
        (await SharedPreferences.getInstance())
            .containsKey(LocaleController.preferenceKey),
        isFalse);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('Arabic settings use RTL and remain usable with enlarged text',
      (tester) async {
    final controller = LocaleController();
    await controller.select(const Locale('ar'));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ListView));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
      'storage failure keeps the setting and displays a localized error',
      (tester) async {
    final controller = LocaleController(
        preferences: () => Future.error(StateError('Storage unavailable')));
    await controller.load();
    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byKey(const ValueKey('language-de')));
    await tester.pumpAndSettle();
    expect(controller.locale, isNull);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
