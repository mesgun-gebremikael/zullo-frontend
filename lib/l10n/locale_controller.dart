import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'locale_catalog.dart';

/// Device preference, intentionally independent of accounts and private data.
class LocaleController extends ChangeNotifier {
  LocaleController({Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;
  static final instance = LocaleController();
  static const preferenceKey = 'zullo.app_language.v1';
  final Future<SharedPreferences> Function() _preferences;
  Locale? _locale;
  Locale? get locale => _locale;
  bool _loaded = false;
  int _revision = 0;
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    final revision = _revision;
    try {
      final preferences =
          await _preferences().timeout(const Duration(seconds: 3));
      final saved = preferences.getString(preferenceKey);
      if (revision == _revision &&
          saved != null &&
          LocaleCatalog.ready.contains(saved)) {
        _locale = LocaleCatalog.fromCode(saved);
      }
    } catch (_) {
      // Platform storage must never prevent startup or system-language fallback.
    }
    _loaded = true;
    notifyListeners();
  }

  bool get loaded => _loaded;

  Future<void> select(Locale? value) async {
    if (value != null &&
        !LocaleCatalog.ready.contains(LocaleCatalog.code(value))) {
      throw ArgumentError.value(value, 'value', 'Language is not ready');
    }
    final revision = ++_revision;
    final preferences =
        await _preferences().timeout(const Duration(seconds: 3));
    if (revision != _revision) return;
    final saved = value == null
        ? await preferences.remove(preferenceKey)
        : await preferences.setString(preferenceKey, LocaleCatalog.code(value));
    if (!saved) throw StateError('Language preference could not be saved');
    if (revision != _revision) return;
    _locale = value;
    notifyListeners();
  }
}
