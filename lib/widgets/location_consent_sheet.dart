import 'package:flutter/material.dart';
import '../l10n/localization.dart';

/// A contextual explanation precedes the system's foreground-only permission.
class LocationConsentSheet extends StatelessWidget {
  const LocationConsentSheet({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.near_me_outlined,
                    size: 38, color: Color(0xFFEC2863)),
                const SizedBox(height: 20),
                Text(context.tr('Hitta personer nära dig'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(
                    context.tr(
                        'Låt ZULLO använda din plats när appen är öppen. Platsen uppdateras automatiskt när du förflyttar dig. Din exakta position visas inte för andra.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.5)),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.tr('Använd min plats'))),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10n.continueLater)),
              ]),
        ),
      );
}
