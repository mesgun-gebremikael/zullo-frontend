# ZULLO settings review — 2026-11-27

Scope: every visible account-settings entry and its linked controls, client lifecycle and corresponding server contract. This records source review and automated verification; it is not certification of physical-device behavior or production readiness.

| Entry/control | Reviewed behavior and changes | Evidence / limits |
| --- | --- | --- |
| Language | Automatic phone language, manual selection and return to automatic; device-local persistence, English fallback, 40 selectable catalogs including German/Dutch. Pending storage cannot notify disposed controllers. | `language_settings_page_test`, `locale_controller_test`, localization checks; Arabic RTL and 200% text tested. Native-speaker review remains required. |
| Notifications | Added localized Android/iOS link to the phone's app settings, duplicate-tap protection and failure feedback. Opening settings does not grant permission. | `settings_privacy_safety_test`; no in-app per-category preferences. Actual OS navigation, match/message delivery and permission recovery require phones. |
| Place and discovery | Saved place, manual GPS, foreground automatic updates, distance/age expansion and error retries reviewed. Old-account actions cannot write after account change. | `discovery_location_lifecycle_test`, service tests; no background tracking. Physical GPS/travel validation remains. |
| Discovery filters | Gender, radius 1–300 km, adult ages 18–100, save/cancel/failure paths. Legacy reversed/out-of-range ages now normalize before rendering. Stale save completion cannot close another account's route. | `discovery_settings_safety_test`; backend strict-first/expanded results tested separately. Expansion is optional and never includes minors. |
| Profile verification | Clearly unavailable; no fake verification or successful verification claim. | A real identity-verification integration is not implemented. |
| Activity / incognito | Preferences remain unknown and disabled until confirmed by server. Failure exposes retry. Each change sends only its own flag; saves disable both controls. Premium eligibility and disabling after expiry remain server-enforced. | `settings_privacy_safety_test`, backend `CommerceTests`; no paid activation. |
| Account email | Read-only authenticated account email, loading/error and working retry; successful retry clears stale error. | Settings regression tests. No email-change feature. Resend/domain setup remains explicitly paused; signup verification must not be bypassed. |
| Blocked profiles | Historical identification cards, list retry, confirmation/cancellation, single pending unblock and account isolation. Session-aware transport handles unauthorized/stale responses. | `settings_account_retry_test`, account/block tests. Full current blocked-profile browsing is intentionally unavailable for privacy. |
| Pause / resume | Confirmed server status, retry, explicit boolean response, no silent success for malformed responses. | Frontend account tests; backend rejects missing/null pause flags. |
| Delete account | Confirmation/password/cancellation and stale-session handling reviewed. Existing deletion safeguards retained. | Account-management tests; no real account or production data deleted. |
| Log out | Confirmation, cancellation, welcome navigation and installation cleanup reviewed. | `logout_navigation_test`, session/installation tests. This is not a revoke-all-sessions feature. |
| Premium and purchases | Monthly/annual offers, native prices, restore, refresh, subscription management and configured legal links reviewed with existing commerce tests. | Checkout remains disabled. Native stores, interrupted receiptless purchases and real payment sandbox validation remain launch gates. |
| Account changes / network | Bound token reads to the initiating session before and after storage access; discovery update payload captured before awaits. Privacy requests cannot overwrite unrelated settings. | `settings_token_epoch_test`; backend endpoint authorization and partial-update tests. |

## Cross-repository verification

The backend contract/persistence matrix is in `zullo-backend/docs/SETTINGS_BACKEND_AUDIT.md`. The focused language/notification review and registration password-byte-limit review are alongside this document. Full-suite results are recorded in project memory after verification.

No production deployment, database migration, paid-service activation, SMTP setup or real purchase was performed. Remaining device/provider gates must stay visible; passing unit/widget tests does not remove them.
