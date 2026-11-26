# Premium, notifications and verified email release candidate

This work prepares the next integration step. It does not activate store billing, create merchant accounts, publish an app or deploy production. Automated tests are evidence of specific behavior; they are not a guarantee of perfect delivery, native language quality or payment-provider availability.

## Product decision

Launch with one **ZULLO Premium** tier and two renewal choices: monthly and annual. Both have the same benefits. This keeps the initial catalog understandable and limits upgrade, cancellation and billing-period combinations. Weekly plans can be evaluated later; they are not required to launch the first supported catalog. Set prices and availability in the stores, not in Dart code.

| Store product | Type | Server-recognized benefit |
| --- | --- | --- |
| `zullo_premium_monthly` | Monthly auto-renewing subscription | Entitlement `premium` |
| `zullo_premium_annual` | Annual auto-renewing subscription | Same entitlement `premium` |
| `zullo_superlikes_5` | Consumable | Five purchased Superlikes |
| `zullo_boost_1` | Consumable | One purchased Boost |
| `zullo_boosts_5` | Consumable | Five purchased Boosts |
| `zullo_hide_activity_monthly` | Existing legacy subscription only | Entitlement `activity_privacy`; no new upsell |

The client also recognizes Google product `zullo_premium` with a `P1M` or `P1Y` base-plan period, mapping these to monthly or annual display choices. The server recognizes the known Google subscription prefix. Verify the exact base-plan identifiers in RevenueCat and the Play test track. Do not assume a store title proves a period or benefit.

Premium provides ordinary-like quota bypass, visibility of ordinary incoming likes, eligible rewind, incognito, activity hiding, three included Superlikes per rolling seven-day allowance and one included Boost per anchored month. Annual billing must not reduce Boosts to one per year. Included credits do not accumulate across allowance windows. Purchased credits remain until used; a verified refund reverses its grant once. Internal refund debt is never displayed as spendable credit.

An existing separate Hide Activity subscription is preserved. Buying Premium does not automatically cancel that subscription; the app discloses overlap and sends the user to native store subscription management. Hiding activity removes the online/recent-activity response for unblocked matches while the entitlement is valid. Incognito remains a separate Premium visibility setting. Neither flag grants chat access to unmatched or blocked people.

## Superlikes and Boost

A Superlike is a distinct server-recorded like, consumes an available included/purchased credit once, and appears with the blue-star identity in eligible discovery and incoming Likes. Free recipients can see incoming Superlikes; ordinary incoming identities remain Premium-gated. A Superlike is not a match: chat still requires reciprocal likes. Blocks, closed accounts and other eligibility rules remain enforced.

Boost consumes one available credit and runs for 30 minutes. Its owner sees server-backed balances and active time/status. There is no public “paid” marker on the person's profile. Boost changes ranking only among profiles that already pass eligibility filters; it does not bypass distance, age, gender, incognito, visibility, blocks or closure. It cannot guarantee views or matches, and it cannot replace a card already cached on another phone.

## Purchase confirmation and restart safety

The backend is the source of entitlements, balances and refund state. The client reserves a per-account checkout guard before invoking the native SDK. An unknown result, interrupted request or corrupted pending record fails closed: the customer is told not to buy again and can reconcile/restore. Logout retains the original account's pending marker; successful account erasure clears its device-local purchase metadata.

A native SDK result identifies the receipt to check, but does not grant credits. Consumables are confirmed against the authenticated server purchase ledger, not by watching whether the balance increased. Spending concurrently on another device must not produce a false pending result, and an unrelated credit grant must not confirm this checkout.

**Receipt identifier integration gate:** a successful `PurchaseResult.storeTransaction.transactionIdentifier` is a store transaction/order identifier. RevenueCat `CustomerInfo.nonSubscriptionTransactions.transactionIdentifier` is a RevenueCat-created identifier in the pinned native bridge. They are not interchangeable. Receiptless/restart recovery must use a server-verified mapping to the actual store-ledger transaction; it must never grant a balance from a client-supplied RevenueCat ID. See the backend rollout document for pinned upstream evidence. A same-product/date-window match is not sufficient to identify the current attempt: an earlier successful purchase or another device can appear while the unknown result is still unresolved. Keep the guard pending unless the current attempt has an exact, verified correlation. Confirm this path in sandbox before enabling checkout.

## Email ownership

A syntactically valid address does not prove the mailbox exists. Common provider typos can be rejected/suggested, but new email accounts must enter a six-digit emailed code before receiving a User identity or bearer token. New registration returns a pending challenge (`202`), not an immediately logged-in account.

Codes expire after 15 minutes, have five verification attempts, a 60-second resend interval and a five-sends-per-hour budget. The backend stores hashes rather than plaintext codes, uses constant-time comparisons, consumes codes transactionally and clears the pending password/code hashes after success. Provider acceptance is recorded even if the requesting browser closes after delivery; an SMTP disconnect failure after acceptance is not treated as an unsent email.

Existing accounts are preserved. Historical `IsVerified` is not presented as proof that old email addresses were verified under this new flow. No accounts are silently deleted, merged or linked to Google identities because an address happens to match.

**SMTP must be configured and tested before public registration.** With no configured sender, new registrations intentionally return `503`; the app must not falsely say a code was sent or fall back to creating an unverified account. Security emails currently use English instructions with the numeric code. In-app verification instructions are localized. Never paste SMTP passwords into chat or commit them.

## Location and discovery

A one-time contextual prompt explains foreground location use. After permission and the automatic-location switch are enabled, foreground polling, resume refresh and cumulative movement update the discovery centre. The update button is a retry/check action, not a requirement for every move. Disabled tracking, denied permission, background state and stale-account requests do not silently restart location access. Native fixes must have finite coordinates and acceptable accuracy.

The relaxed-distance and relaxed-age flags affect real server candidates. Strict preferences are tried first; fallback is used only when the strict candidate pool is empty and the relevant switch is enabled. Age expansion is at most five years on either side and never below 18. Gender, block, visibility, incognito and account-state restrictions are not relaxed. Unknown legacy `0,0` coordinates do not fabricate nearby matches. Emulator GPS must be set in the emulator's own location controls.

The empty-discovery ZULLO mark has subtle rotating/pulsing colour. Motion stops for paused discovery, hidden/disabled animation, reduced-motion accessibility and background state. It is decorative feedback, not a claim that an unanswered network search is running continuously.

## Profile questions

“Friends” is now displayed as “Find new friends.” Up to three distinct conversation questions, each with an answer of at most 250 characters, can be saved through onboarding, drafts, editing and full-profile display. Legacy first-question fields remain compatible. Reading old data recovers its existing question; an old-client first-question update preserves the other answers instead of silently deleting them. Changing a question preserves the written answer until the user removes it explicitly.

## Notifications and account privacy

A first committed match schedules notifications for both recipients through an IDs-only outbox. Delivery resolves current permission, relation, account state and device ownership rather than trusting a payload-supplied profile. Retries are bounded, with stable notification identity/collapse metadata. Pausing discovery does not mute an existing chat or match notice. Blocking, unmatching and closure revoke future eligible sends. A push already accepted by an OS/provider cannot be recalled reliably.

OS-rendered alerts must not expose another account's message preview on a shared phone. The final release must include versioned installation/token ownership, stale-claim rejection and generic message alert copy; the client still validates recipient and session before opening a conversation. Native resource strings follow the OS language. Flutter's manual in-app language choice does not itself change the phone's native notification-resource language.

## Configuration before any billing activation

Server secrets:

- `Commerce__Enabled=false` until the owner explicitly approves activation after sandbox tests.
- `Commerce__RevenueCatSecretKey` — server secret key, never shipped in Flutter.
- `Commerce__WebhookAuthorization` — a long random complete Authorization-header value, at least 32 characters, also configured in RevenueCat.
- `Commerce__AllowSandbox=true` only for non-production testing. Production rejects sandbox events.

Flutter public build-time values:

- `REVENUECAT_IOS_PUBLIC_KEY` (`appl_...`)
- `REVENUECAT_ANDROID_PUBLIC_KEY` (`goog_...`)
- `ZULLO_TERMS_URL` and `ZULLO_PRIVACY_URL` — actual public HTTPS documents.

Configure RevenueCat with identified ZULLO user UUIDs and restore behavior that preserves the original purchase owner. Webhooks go to `https://<api-host>/commerce/webhook`. Both stores need configured products, licensed/sandbox users, correct permanent app IDs, legal text, signing and review. Store payouts/tax/bank setup belongs in the stores' merchant systems; RevenueCat verification does not establish those accounts.

## Required checks before launch

- Signed physical-device tests: notification permission allowed/denied, foreground/background/cold start, logout/account switch, queued old notifications, match deduplication, blocks/unmatch/closure and APNs/FCM delivery.
- GPS permission, precise/approximate/unavailable fixes, travel/resume, tracking off, and empty strict/fallback feeds on real Android/iPhone phones.
- Successful/cancelled/pending/interrupted checkout; exact receipt recovery after restart, same/different ZULLO account, restore, renewal, annual monthly allowances, grace, refund before/after spending, duplicate/out-of-order/delayed webhooks, provider outage and production rejection of sandbox events.
- Native SMTP delivery, actual inbox/spam placement, resend and expired/invalid/replayed codes, and unchanged access for legacy accounts.
- v9-to-v10 secure-storage upgrade on existing installations, real photo upload/display, native font/RTL layout and native-speaker review.
- Profile/signing/store requirements and performance measurements on release/profile builds. Debug APK and simulator compilation alone do not prove store readiness.

Coordinate the updated frontend with the new email-registration API and additive migration. An older client expecting registration `200`/JWT cannot finish the new `202` challenge. There is no insecure compatibility fallback. See `docs/VERIFIED_EMAIL_MATCH_AND_PREMIUM_ROLLOUT.md` in the backend repository and retain checkout off throughout this staged rollout.
