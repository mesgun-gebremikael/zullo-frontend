# International release work

## Behavior

The app follows the phone's preferred supported language, with English fallback. Profile → Settings → App language provides a persistent device preference and an automatic option. Language choice is not inferred from download country, account nationality or GPS. Chinese regional preferences resolve to the appropriate Simplified/Traditional script; Norwegian aliases resolve to Bokmål. Flutter's official ARB generation and Material/Cupertino/Widgets delegates provide translated system controls and text direction. Arabic, Persian, Hebrew and Urdu use RTL.

Only complete catalogs listed in `LocaleCatalog.ready` are offered. Each catalog must contain every source message, preserve typed interpolation placeholders/newlines, and pass `.ci/check_localizations.py`. Generated Dart is recreated by Flutter rather than edited manually. Canonical profile choices retain stable stored identifiers and translate at display time. Names, messages, biographies, prompt answers, jobs and cities remain user-authored text. The source adapter covers existing canonical choice labels and application error strings while explicit UI calls use generated getters.

## Profile and navigation

The full profile gallery supports page swiping, tapping either side and explicit previous/next buttons, with directional controls for RTL. Swipe cards reserve room for their action row and the bottom navigation. Rewind appears before dismiss; redundant branding/profile/edit controls are removed. Friendship joins the relationship choices. Religion is optional without a separate private option; existing private values stay hidden. Conversation prompts use a card picker and twelve stable identifiers. Blocked cards show permitted identification, while the backend preserves access restrictions.

## Dependencies and validation

See [DEPENDENCY_UPGRADE.md](DEPENDENCY_UPGRADE.md) for supported SDK/dependency ranges, the Firebase contract and secure-storage migration bridge. Analyzer debt is removed rather than added to a suppression baseline. CI verifies all catalogs, Flutter tests, analyzer, native prerequisite checks, Android compilation, iOS simulator compilation and web compilation.

Backend companion PR21 adds safe blocked-card snapshots and seven prompt identifiers. Apply its additive migration before the frontend update. No production deployment, payment activation or destructive migration is part of this work.

## Release limits

Automated catalog checks establish structural completeness, not native-speaker certification. Translations are authored and reviewed with AI; native linguistic review of all offered languages remains a release QA task. Device checks remain required for layout/font shaping, permission-denied and allowed GPS flows, location changes, actual photos/uploads, push delivery and existing-v9 secure-storage migration. Store signing and Apple/APNs provisioning remain prerequisites; Android debug/simulator success does not establish store readiness. Do not call the release perfect or fully ready until these checks are completed.
