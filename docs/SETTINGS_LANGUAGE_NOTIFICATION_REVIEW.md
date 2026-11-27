# Language and notification settings review — 2026-11-27

Scope: `LanguageSettingsPage`, `LocaleController`, `LocaleCatalog`, notification
startup/access handlers and the current profile settings entry points. This is a
source/widget-test review, not a physical-device permission or delivery test.

## Controls checked

| Control/behavior | Result |
| --- | --- |
| Follow phone language | A null app override uses Flutter locale-list resolution. Unsupported languages fall back to English. |
| Manual language selection | Saves a device preference, updates the displayed app and survives controller restart. It is intentionally independent of accounts. |
| Return to automatic | Removes the saved override. Tested through the settings page after German and Dutch selection. |
| Available language list | 40 ready catalog codes; includes Deutsch (`de`) and Nederlands (`nl`). Draft/unknown codes are rejected. |
| Chinese/Norwegian resolution | Traditional/Simplified Chinese regions and Norwegian alias have controller/catalog regression coverage. |
| Arabic and large text | RTL verified through official localization delegates; settings remain usable at 200% text scaling. Existing compact-screen localization tests also cover Arabic. |
| Save failure | Leaves the previous language selected and displays the localized save error. |
| Slow startup storage | Cannot overwrite a more recent explicit selection; failure does not block startup. |
| Disposal during storage work | Fixed: pending load/save can finish without notifying a disposed controller; save remains persisted. |

## Notifications: actual current behavior

- Profile/account settings contain no per-category notification switches.
  Root integration now adds an explicitly labelled mobile OS-settings link for
  Android/iOS, with fully localized title/description, duplicate-tap protection
  and launch-failure feedback. Permission remains managed by the phone OS;
  opening settings never grants permission automatically. The widget link is
  regression tested; actual OS navigation/delivery still requires devices.
- Startup requests native permission and registers token refresh independently
  from cold-start notification lookup. Registration failure does not stop the app
  or discard an otherwise authorized cold-start event.
- The initial-message lookup has a five-second timeout. Chat/match routing checks
  recipient/account generation, current relation access and trusted profile data;
  stale or unauthorized payloads cannot open another account's chat.
- Android channel labels follow the displayed app language. Background native
  notification resource text follows the OS language; manually selecting an app
  language does not imply native background text follows it.
- Tests cover denied relation/recipient checks, account changes during awaits,
  malformed payloads, exactly-once startup and nonblocking registration/labels.

## Remaining external validation

Real Android/iPhone permission grant/deny/re-enable, APNs/FCM token refresh,
background/terminated delivery, lock-screen privacy and tapping notifications
must still be tested on physical devices. Translation completeness and widget
layout checks do not certify native-speaker translation quality.

Targeted validation log: `/workspace/shared/settings-language-tests.log`.
