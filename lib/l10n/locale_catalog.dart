import 'package:flutter/widgets.dart';

/// Only complete, validated catalogs belong here. Draft ARBs are not selectable.
class LocaleCatalog {
  static const ready = <String>{'en', 'sv'};
  static const nativeNames = <String, String>{
    'en': 'English',
    'sv': 'Svenska',
    'da': 'Dansk',
    'nb': 'Norsk bokmål',
    'fi': 'Suomi',
    'de': 'Deutsch',
    'fr': 'Français',
    'es': 'Español',
    'it': 'Italiano',
    'pt': 'Português',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'cs': 'Čeština',
    'ro': 'Română',
    'el': 'Ελληνικά',
    'uk': 'Українська',
    'ru': 'Русский',
    'tr': 'Türkçe',
    'ar': 'العربية',
    'he': 'עברית',
    'fa': 'فارسی',
    'ur': 'اردو',
    'hi': 'हिन्दी',
    'bn': 'বাংলা',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'zh_Hans': '简体中文',
    'zh_Hant': '繁體中文',
    'ja': '日本語',
    'ko': '한국어',
    'th': 'ไทย',
    'vi': 'Tiếng Việt',
    'id': 'Bahasa Indonesia',
    'ms': 'Bahasa Melayu',
    'sw': 'Kiswahili',
    'am': 'አማርኛ',
    'af': 'Afrikaans',
    'zu': 'isiZulu',
    'fil': 'Filipino',
    'hu': 'Magyar',
  };

  static String code(Locale locale) => locale.scriptCode == null
      ? locale.languageCode
      : '${locale.languageCode}_${locale.scriptCode}';

  static Locale fromCode(String code) {
    final parts = code.split('_');
    return Locale.fromSubtags(
        languageCode: parts.first,
        scriptCode: parts.length > 1 ? parts[1] : null);
  }

  static List<Locale> get supported =>
      ready.map(fromCode).toList(growable: false);

  static String name(Locale locale) =>
      nativeNames[code(locale)] ?? code(locale);

  static Locale resolve(List<Locale>? preferred, Iterable<Locale> supported) {
    final available = {for (final locale in supported) code(locale): locale};
    for (final locale in preferred ?? const <Locale>[]) {
      var key = code(locale);
      if (locale.languageCode == 'zh' && locale.scriptCode == null) {
        key = const {'TW', 'HK', 'MO'}.contains(locale.countryCode)
            ? 'zh_Hant'
            : 'zh_Hans';
      }
      if (locale.languageCode == 'no') key = 'nb';
      final exact = available[key];
      if (exact != null) return exact;
      final language = available[locale.languageCode];
      if (language != null) return language;
    }
    return available['en'] ?? const Locale('en');
  }
}
