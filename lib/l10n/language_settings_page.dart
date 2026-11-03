import 'package:flutter/material.dart';
import 'localization.dart';
import 'locale_catalog.dart';
import 'locale_controller.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key, this.controller});
  final LocaleController? controller;

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  LocaleController get controller =>
      widget.controller ?? LocaleController.instance;
  bool _saving = false;

  Future<void> _select(Locale? locale) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await controller.select(locale);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.languageSavedError),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(strings.languageSettingsTitle)),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView(
          children: [
            ListTile(
              title: Text(strings.languageAutomatic),
              subtitle: Text(strings.languageAutomaticDescription),
              trailing:
                  controller.locale == null ? const Icon(Icons.check) : null,
              selected: controller.locale == null,
              enabled: !_saving,
              onTap: () => _select(null),
            ),
            const Divider(),
            for (final locale in LocaleCatalog.supported)
              ListTile(
                key: ValueKey('language-${LocaleCatalog.code(locale)}'),
                title: Text(LocaleCatalog.name(locale)),
                trailing: controller.locale == locale
                    ? const Icon(Icons.check)
                    : null,
                selected: controller.locale == locale,
                enabled: !_saving,
                onTap: () => _select(locale),
              ),
          ],
        ),
      ),
    );
  }
}
