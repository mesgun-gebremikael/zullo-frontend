# App review and release checklist

This change fixes the reviewed onboarding, authentication and image-loading paths. It is not a claim that every line of the app is rewritten, every defect is eliminated, or production/mobile performance is certified.

## Implemented and covered

| Area | Result | Evidence |
|---|---|---|
| Leaving profile setup | Confirmation precedes saving and logout; cancel stays put. Both Android back and the close action use the same behavior. | Navigation widget tests, including late logout/account switch |
| Returning after leaving | Existing credentials log into the existing account; unfinished setup loads its private saved answers and step. Duplicate signup remains rejected. | Registration tests, resume widget test, draft API tests |
| Autosave | One model/controller, debounced serialized writes, encrypted per-account local outbox, private server draft with revisions. No public Profile is created by autosave. | Draft persistence/recovery and real PostgreSQL tests |
| Multiple devices/offline | Stale versions cannot overwrite; lost acknowledgements reconcile; local data survives failed network saves. Replacing unsynced local answers requires an explicit choice. | Controller tests and concurrent PostgreSQL PUT tests |
| Account closure/completion | Server draft is removed transactionally; accepted local account closure and profile completion clear the local outbox where device storage works. | Account, profile and draft tests |
| Required fields | Required answers gate progression; profile publication requires valid server fields, owner-bound images and at least two photos for a new profile. Optional answers remain blank unless selected. | Required/optional form tests and backend profile validation |
| Layout | One scrollable form for all 19 steps, consistent progress/actions, keyboard-safe content, accessible selection states and readable save errors. | Every step checked at 360×640 with keyboard inset and enlarged text |
| Authentication | Password spaces preserved; duplicate submissions guarded; successful login clears auth-screen history and delegates profile routing to the bounded splash flow. | Login, registration, logout and startup tests |
| Slow connections | Remaining core profile/feed/swipe/report requests have finite deadlines. A failure preserves existing data instead of treating it as an empty profile. | Existing startup/session and API regressions |
| Images | One cached provider for card prefetch/load/display; bounded preview/avatar decode sizes; fewer speculative images. A late photo cannot appear on the next user's card. No random stock photo substitutes for a missing personal image. | Controlled image-completion test; source review of prefetch paths |

## Code structure

The old duplicated onboarding pages are removed. The questions/options live in `onboarding_steps.dart`, answer serialization in `onboarding_data.dart`, sync/recovery in `profile_setup_controller.dart`, transport/encrypted storage in `onboarding_draft_service.dart`, and the responsive view in `onboarding_wizard.dart`. Exit confirmation is shared. The view is the largest new file; it renders one question at a time, rather than building 19 screens in a navigator stack.

Core request deadlines and a common `ProfileImages` provider also improve existing screens. Removed unused imports and a few mechanical analyzer findings. The existing chat coordinator, session generation checks, lazy tab initialization and request coalescing were retained after review rather than replaced.

There is still technical debt: `edit_profile_page.dart`, `chat_page.dart`, `home_page.dart`, `main.dart` and `main_navigation.dart` are large UI/state files. They contain working service boundaries and tested race handling; their size alone does not prove they are broken, but extracting smaller components should be incremental and keep those contracts. The analyzer baseline records remaining older warnings/deprecations; passing it does not mean zero findings. No performance claim is based merely on a successful debug build.

## Data and photo retention

Draft text stays private on the account until completion or account closure. Set a business/privacy retention policy for inactive draft text before public launch. Local unsynced data is encrypted and keyed by account; logout retains it for resume on that device. Remote deletion cannot recall copies previously downloaded on another device; device storage failures and provider backup retention are separate operational concerns.

Selected managed draft photos get a seven-day attachment window refreshed by a successful draft save. Removing a selected draft photo queues erasure. Unregistered uploads keep the existing shorter orphan expiry. On return after expiry, missing photos are reported/re-uploaded while other answers remain. Photo ownership and account-closure cleanup continue to use the ledger and verified Cloudinary worker; no unsigned uploads are restored.

## Deployment order and manual verification

Deploy the backend `PrivateOnboardingDrafts` migration before this frontend. Existing completed profiles need no draft and are not recreated. Keep Cloudinary credentials only on the backend. Do not roll back a table containing active private drafts without a reviewed data-preservation plan.

All real owner tests below remain unconfirmed. Earlier screenshots ran old unsigned-upload code; later emulator navigation/startup failures do not count as successful Cloudinary tests.

- [ ] Update the local checkout, start one emulator with the full staging URL flag, verify the installed build.
- [ ] Android and iOS: complete a new profile; keyboard, large text, pickers, background/resume and system back.
- [ ] Leave/cancel on the first and a later step; log in again on the same device and a second device; check every saved value and position.
- [ ] Disconnect/reconnect network while typing and while saving; do not lose answers or overwrite a newer device.
- [ ] Verify actual Cloudinary upload, saved removal, account closure during upload, CDN invalidation and reviewed legacy-image cleanup.
- [ ] Profile a release/profile build on real Android and iPhone: first usable frame, scrolling/swipe frame times, repeated photo changes, memory and slow network. Five simultaneous debug emulators are not a production performance benchmark.
- [ ] Complete the existing payment sandbox, verification-provider, legal/retention and store/device-signing work from the release checklist.

A free/sleeping backend can still introduce cold-start delay. Local request deadlines make that failure recoverable; they do not replace hosting capacity or network availability.
