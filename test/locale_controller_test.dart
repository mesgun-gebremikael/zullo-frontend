import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/l10n/locale_catalog.dart';
import 'package:zullo_app/l10n/locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('default follows the system; unavailable languages fall back to English',
      () async {
    final controller = LocaleController();
    await controller.load();
    expect(controller.locale, isNull);
    expect(LocaleCatalog.resolve([const Locale('xx')], LocaleCatalog.supported),
        const Locale('en'));
    expect(
        LocaleCatalog.resolve(
            [const Locale('sv', 'FI')], LocaleCatalog.supported),
        const Locale('sv'));
    controller.dispose();
  });

  test(
      'manual selection persists across controller restart and can return to automatic',
      () async {
    final first = LocaleController();
    await first.load();
    await first.select(const Locale('sv'));
    final restarted = LocaleController();
    await restarted.load();
    expect(restarted.locale, const Locale('sv'));
    await restarted.select(null);
    final third = LocaleController();
    await third.load();
    expect(third.locale, isNull);
    first.dispose();
    restarted.dispose();
    third.dispose();
  });

  test('incomplete saved catalog is never selected', () async {
    SharedPreferences.setMockInitialValues(
        {LocaleController.preferenceKey: 'xx'});
    final controller = LocaleController();
    await controller.load();
    expect(controller.locale, isNull);
    expect(() => controller.select(const Locale('xx')), throwsArgumentError);
    controller.dispose();
  });

  test('Chinese region and Norwegian aliases resolve to supported scripts', () {
    const supported = [
      Locale('en'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      Locale('nb')
    ];
    expect(
        LocaleCatalog.code(
            LocaleCatalog.resolve([const Locale('zh', 'TW')], supported)),
        'zh_Hant');
    expect(
        LocaleCatalog.code(
            LocaleCatalog.resolve([const Locale('zh', 'CN')], supported)),
        'zh_Hans');
    expect(LocaleCatalog.resolve([const Locale('no', 'NO')], supported),
        const Locale('nb'));
  });

  test('storage failure does not block startup or change the selected locale',
      () async {
    final controller = LocaleController(
        preferences: () => Future.error(StateError('Unavailable')));
    await controller.load();
    expect(controller.loaded, isTrue);
    expect(controller.locale, isNull);
    await expectLater(controller.select(const Locale('sv')), throwsStateError);
    expect(controller.locale, isNull);
    controller.dispose();
  });

  test('slow startup read cannot overwrite a newer manual selection', () async {
    final pending = Completer<SharedPreferences>();
    var reads = 0;
    final preferences = await SharedPreferences.getInstance();
    final controller = LocaleController(
        preferences: () =>
            ++reads == 1 ? pending.future : Future.value(preferences));
    final loading = controller.load();
    await controller.select(const Locale('sv'));
    pending.complete(preferences);
    await loading;
    expect(controller.locale, const Locale('sv'));
    controller.dispose();
  });
}
