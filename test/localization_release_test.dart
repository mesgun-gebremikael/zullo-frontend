import 'package:zullo_app/welcome_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/l10n/app_localizations.dart';
import 'package:zullo_app/l10n/locale_catalog.dart';
import 'package:zullo_app/l10n/locale_controller.dart';
import 'package:zullo_app/l10n/language_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every offered language loads an official catalog and Material widgets',
      () async {
    for (final locale in LocaleCatalog.supported) {
      expect(AppLocalizations.delegate.isSupported(locale), isTrue,
          reason: '$locale');
      final strings = await AppLocalizations.delegate.load(locale);
      expect(strings.languageSettingsTitle, isNotEmpty);
      expect(strings.profileStep('7', '19'), contains('7'));
      expect(strings.profileStep('7', '19'), contains('19'));
      expect(strings.unblockPersonQuestion('Dackhem'), contains('Dackhem'));
      expect(GlobalMaterialLocalizations.delegate.isSupported(locale), isTrue,
          reason: '$locale');
      expect(GlobalCupertinoLocalizations.delegate.isSupported(locale), isTrue,
          reason: '$locale');
    }
  });

  for (final locale in LocaleCatalog.supported) {
    testWidgets('welcome actions remain usable in $locale on a compact screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = await AppLocalizations.delegate.load(locale);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: LocaleCatalog.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: const WelcomePage(),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(strings.logIn));
      expect(
          find.widgetWithText(OutlinedButton, strings.logIn), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, strings.createAccount),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in [
    const Locale('en'),
    const Locale('sv'),
    const Locale('ar'),
    const Locale('de')
  ]) {
    testWidgets(
        'language settings is usable at compact size with enlarged text: $locale',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = LocaleController();
      addTearDown(controller.dispose);
      // Skip draft catalogs until they are validated and offered.
      if (!LocaleCatalog.supported.contains(locale)) return;
      BuildContext? pageContext;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: LocaleCatalog.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: Builder(builder: (context) {
          pageContext = context;
          return LanguageSettingsPage(controller: controller);
        }),
      ));
      await tester.pumpAndSettle();
      expect(Directionality.of(pageContext!),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      expect(find.byKey(const ValueKey('language-en')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('language-en')));
      await tester.pumpAndSettle();
      expect(controller.locale, const Locale('en'));
      expect(tester.takeException(), isNull);
    });
  }
}
