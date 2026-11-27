# Registration password length review — 2026-11-27

New account registration now rejects passwords above 72 UTF-8 bytes before sending a request, matching the backend BCrypt registration boundary. The existing minimum-eight rule remains. Customer text says “Choose a shorter password.” because a byte limit must not be described as a character limit. Existing login and password confirmation flows are unchanged so legacy credentials remain usable.

Added the message to all 40 selectable catalogs and the base Chinese fallback catalog; all selectable catalogs contain 545 messages. Updated the canonical source manifest and regenerated the source adapter using `tool/generate_source_adapter.py`; regenerated official Flutter localizations with `flutter gen-l10n` (generated files are ignored).

Validation: 17 tests passed across registration_password_limit_test.dart (10 new), registration_flow_test.dart and login_form_test.dart. New coverage includes 72/73-byte ASCII, 36/37 Swedish letters and 18 emoji/18 emoji plus ASCII boundaries, request prevention, English/German/Dutch/Arabic display and Arabic RTL. Targeted analyzer passed. `.ci/check_localizations.py` passed for 40 complete catalogs. Translations are AI-authored; native-language review remains a launch gate, and these tests do not claim that human review or native device validation occurred.

Changed files for this subtask: lib/register_page.dart; lib/l10n/app_*.arb (41 catalogs); lib/l10n/localization.dart; tool/catalog_manifest.json; test/registration_password_limit_test.dart; this document. No AuthService, login, account confirmation, production configuration, paid service, or database changes. No commit or push performed.

## Additional notification-settings catalog pass

Added `notificationSettingsTitle` and `notificationSettingsDescription` with real translations across all 40 selectable languages and base Chinese. These labels describe the operating system settings link, not in-app notification category preferences. Canonical source mappings use “Notiser” and “Hantera notiser i mobilens inställningar.” Official localizations and the compatibility adapter were regenerated. Catalog checks now pass with **547** complete messages in each selectable language. No registration logic changed in this pass.
