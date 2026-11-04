import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zullo_app/l10n/app_localizations.dart';
import 'package:zullo_app/l10n/app_localizations_ar.dart';
import 'package:zullo_app/l10n/app_localizations_en.dart';
import 'package:zullo_app/l10n/app_localizations_pl.dart';
import 'package:zullo_app/l10n/app_localizations_ru.dart';
import 'package:zullo_app/l10n/app_localizations_uk.dart';
import 'package:zullo_app/l10n/presence_text.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  test('presence selects typed minute/hour/day messages at actual boundaries',
      () {
    final strings = AppLocalizationsEn();
    final now = DateTime.utc(2026, 11, 3, 12);
    String format(Duration ago) =>
        PresenceText.format(now.subtract(ago), now: now, strings: strings);
    expect(PresenceText.format(null, now: now, strings: strings), '');
    expect(format(const Duration(seconds: 89)), strings.onlineNow);
    expect(format(const Duration(seconds: 90)), 'Last active 1 minute ago');
    expect(format(const Duration(minutes: 59)), 'Last active 59 minutes ago');
    expect(format(const Duration(minutes: 60)), 'Last active 1 hour ago');
    expect(format(const Duration(hours: 23)), 'Last active 23 hours ago');
    expect(format(const Duration(hours: 24)), 'Last active 1 day ago');
    expect(format(const Duration(days: 21)), 'Last active 21 days ago');
    expect(format(const Duration(seconds: -20)), strings.onlineNow);
  });

  test('Slavic relative-time forms distinguish 1, 2, 5 and 21', () {
    final ru = AppLocalizationsRu();
    expect(ru.lastActiveMinutes(1), 'Последняя активность: 1 минуту назад');
    expect(ru.lastActiveMinutes(2), 'Последняя активность: 2 минуты назад');
    expect(ru.lastActiveMinutes(5), 'Последняя активность: 5 минут назад');
    expect(ru.lastActiveMinutes(21), 'Последняя активность: 21 минуту назад');
    final pl = AppLocalizationsPl();
    expect(pl.lastActiveHours(1), 'Ostatnia aktywność: 1 godzinę temu');
    expect(pl.lastActiveHours(2), 'Ostatnia aktywność: 2 godziny temu');
    expect(pl.lastActiveHours(5), 'Ostatnia aktywność: 5 godzin temu');
    expect(pl.lastActiveHours(21), 'Ostatnia aktywność: 21 godzin temu');
    final uk = AppLocalizationsUk();
    expect(uk.lastActiveDays(1), 'Остання активність: 1 день тому');
    expect(uk.lastActiveDays(2), 'Остання активність: 2 дні тому');
    expect(uk.lastActiveDays(5), 'Остання активність: 5 днів тому');
    expect(uk.lastActiveDays(21), 'Остання активність: 21 день тому');
  });

  test('Arabic zero, one, two, few, many and other forms stay grammatical', () {
    final strings = AppLocalizationsAr();
    expect(strings.lastActiveMinutes(0), endsWith('دقيقة'));
    expect(strings.lastActiveMinutes(1), 'آخر نشاط قبل دقيقة واحدة');
    expect(strings.lastActiveMinutes(2), 'آخر نشاط قبل دقيقتين');
    expect(strings.lastActiveMinutes(3), endsWith('دقائق'));
    expect(strings.lastActiveMinutes(11), endsWith('دقيقة'));
    expect(strings.lastActiveMinutes(100), endsWith('دقيقة'));
    expect(strings.lastActiveHours(2), 'آخر نشاط قبل ساعتين');
    expect(strings.lastActiveDays(2), 'آخر نشاط قبل يومين');
  });

  test('every official locale formats all relative-time plural boundaries',
      () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final strings = await AppLocalizations.delegate.load(locale);
      for (final count in [0, 1, 2, 3, 5, 11, 21, 100]) {
        for (final text in [
          strings.lastActiveMinutes(count),
          strings.lastActiveHours(count),
          strings.lastActiveDays(count)
        ]) {
          expect(text, isNotEmpty, reason: '$locale / $count');
          expect(text, isNot(contains('{count}')), reason: '$locale / $count');
          if (locale.languageCode != 'sv') {
            expect(text, isNot(contains('Senast aktiv')),
                reason: '$locale / $count');
          }
        }
      }
    }
  });
}
