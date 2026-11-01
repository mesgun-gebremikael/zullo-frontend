# ZULLO Premium: implementation and activation

## Current state

The code implements account-bound server credits, distinct Superlikes, 30-minute Boost ranking, Premium incoming likes, ordinary-like quota bypass (not anti-spam bypass), rewind of an unpaired ordinary swipe, incognito and paid activity hiding. The payment bridge uses RevenueCat with native Apple/Google purchases and server-side verification. **Real purchases remain disabled by default. No store account, RevenueCat account, payout profile or customer payment has been created or activated.**

The owner has confirmed no Google Play developer account yet; the previously discussed Apple Developer membership was not paid. Actual store sandbox/restore/renewal/refund tests and signed device delivery remain blocked on those accounts and configuration. Automated tests use synthetic provider responses and transactions; they do not certify live store billing.

## Product catalog (prices are not hardcoded)

| Identifier | Store type | Benefit |
| --- | --- | --- |
| zullo_premium_monthly | Monthly auto-renewing subscription | Premium entitlement `premium`, includes activity hiding |
| zullo_hide_activity_monthly | Monthly auto-renewing subscription | Only activity hiding, entitlement `activity_privacy` |
| zullo_superlikes_5 | Consumable / one-time product | 5 purchased Superlikes |
| zullo_boost_1 | Consumable / one-time product | 1 purchased Boost |
| zullo_boosts_5 | Consumable / one-time product | 5 purchased Boosts |

Google subscription base-plan suffixes are normalized when matching the catalog. Configure a monthly base plan for the monthly product. Set actual local prices in App Store Connect / Google Play Console and put these packages in the current RevenueCat offering. The app displays the store's localized price, including currency. Previously discussed 59/29/19/79 SEK amounts were proposals, not activated prices.

Premium includes three Superlikes per rolling seven-day allowance and one Boost per verified billing period. Included allowances do not stack. Purchased credits persist on the ZULLO account until consumed. A refund reverses the grant once; already consumed credits may leave a negative internal purchased balance, which is never displayed as spendable credit. Active membership is determined on the server, not by the phone. Standalone activity privacy does not grant Premium, incognito, rewind, included credits or ordinary-like quota bypass. It renews monthly at the store-configured price and can be restored. Buying it does not silently change the visibility switch: turn activity off in Mitt konto afterward. Do not buy it while Premium already includes the benefit; the app disables that redundant purchase. An existing standalone subscription does not automatically cancel when buying Premium: manage it in the store to avoid overlapping charges, as disclosed in the app. Validate cross-product upgrade/cancellation behavior before launch. Subscription cancellation keeps access to the verified paid-through date; expiration/refund updates come through verified provider state.

## Before enabling any real purchases

1. Create/complete Apple Developer and Google Play developer accounts. The owner enters tax and bank details in the stores' own merchant/payout profiles. Apple/Google collect customer payments and pay the owner after fees/taxes according to their payment schedules. RevenueCat is a separate verification service, with separate pricing to review; it is not the payout destination.
2. Confirm permanent store app IDs before creating products. Current Android applicationId is `com.example.zullo_app`; current registered iOS bundle ID is `com.mesgungebremikael.zullo`. Do not rename identifiers or reuse different Firebase configs casually. Decide the final Android ID before Play publication and update Firebase registration if it changes.
3. Connect both store apps to the owner's RevenueCat project. Enable server notifications and configure restore behavior to **keep purchases with the original identified App User ID**, not transfer purchases across ZULLO accounts. The SDK is configured with the signed-in ZULLO user UUID, never an anonymous buyer.
4. Publish real purchase terms and privacy policy, including provider/data disclosures, and configure their public HTTPS URLs.
5. Use separate durable production and staging databases and provider environments. Do not promote sandbox credit balances or the temporary free staging DB into a paid production service. Verify backup/restore preserves the credit ledger and spent balances before launch.
6. Complete the sandbox test matrix below and App Store / Play review before enabling live products.

## Configuration

Server secrets belong in the deployment secret/environment system, never in Flutter or the repository:

- `Commerce__Enabled=false` by default. Only switch on after provider setup and testing.
- `Commerce__RevenueCatSecretKey`: RevenueCat server secret (`sk_...`).
- `Commerce__WebhookAuthorization`: long random secret, at least 32 characters; configure the **exact same complete Authorization header value** in RevenueCat.
- `Commerce__AllowSandbox=true`: explicit testing opt-in for Staging only. Production rejects sandbox receipts/events even if this flag is true.

Configure RevenueCat to send purchase, non-renewing purchase, renewal, cancellation, expiration, transfer and billing events to `https://<api-host>/commerce/webhook`. The endpoint verifies its authorization header, fetches subscriber ownership/entitlements from the fixed RevenueCat API, and uses known SKUs plus canonical store transaction IDs for credit grants/refunds. Legacy v1 records with only a RevenueCat ID wait for the trusted purchase webhook, rather than treating that ID as a store transaction and granting twice. Refunded transactions have tombstones so an earlier refund cannot be undone by a late purchase event. Duplicate notifications and concurrent sync are idempotent.

Flutter build-time public configuration (these are public SDK keys, not server secrets):

- `REVENUECAT_IOS_PUBLIC_KEY`
- `REVENUECAT_ANDROID_PUBLIC_KEY`
- `ZULLO_TERMS_URL`
- `ZULLO_PRIVACY_URL`

Without the server gate, matching public SDK key and legal URLs, there is no buy button. No placeholder prices are charged. Restore and server sync do not recreate spent consumables. A completed store flow whose webhook has not arrived shows a pending-verification message and tells the customer not to buy again.

## Deployment

Deploy the backend first. Migration `AddStandaloneActivityPrivacy` adds the nullable verified activity subscription expiry column. Deploy this backend migration before the corresponding new app. Migration `AddPremiumCommerce` adds CommerceAccounts, PurchaseGrants and Likes.IsSuperLike; old likes default to ordinary likes. Apply it with the existing reviewed migration/staging startup process before using the new endpoints. Deploy/rebuild Flutter afterward. Keep checkout off until store configuration is ready. No real balances are seeded automatically, and there is no public grant/debug endpoint.

## Required manual store/device tests

- Successful and cancelled purchase; pending parental approval; interrupted/lost response; restart and restore on the same ZULLO account; another ZULLO account on the same device cannot inherit credits.
- Renewal, auto-renew cancellation with paid access retained, expiration, grace period, refund before and after spending, delayed/duplicate/out-of-order webhooks, provider outage/retry and sandbox rejection in production.
- Superlike deducts once, appears blue with “Har supergillat dig” in eligible discovery and incoming likes, sends a notification when allowed, and still needs a reciprocal like before chat. A blocked target consumes no credit. Test foreground, background and cold-start notifications on both platforms.
- Boost activation deducts once, shows a countdown, cannot activate twice concurrently, and expires after 30 minutes. Ranking still respects visibility, gender, age, distance, incognito and blocks. Priority affects fetched feeds; it does not guarantee views or matches or replace every already-cached card on other devices.
- Test standalone activity purchase/restore, refund, grace, expiry, cancellation through the paid-through date, Premium inclusion and the redundant-purchase guard. Confirm no extra benefits are granted, both API timestamp responses are hidden and overlapping subscriptions are explicitly managed before launch.
- Incognito is server-enforced; activity hiding removes the timestamp from both presence and match responses. Only unblocked matches can query activity. Foreground heartbeats run once per minute; “Online nu” is a recent-activity indicator with a 90-second freshness window, not proof of continuous human presence.
- Incoming ordinary likes are server-gated to Premium; Superlikes remain visible to free recipients. Rewind cannot remove an existing match, refund a Superlike, or bypass blocks.

## Earlier manual testing still pending

The owner explicitly wants to test later. Registration/automatic login, logout, single name entry, optional choices, required age/photos, notification/chat/reconnect/profile editing, discovery refresh, plus PR12 preference/email/block/unblock changes still need confirmation on the owner's two emulators. Those are not marked complete by this work. Remind the owner when resuming manual testing.

Native validation includes unsigned iOS simulator compilation and an Android debug APK build. Real billing still needs store-connected test builds, licensed test users and the relevant Apple sandbox/TestFlight and Play test-track setup; a successful debug compile does not prove that purchases or payouts work.

## Presentation and activity controls

Profile uses white rounded purchase cards, a blue Superlike star and ZULLO letter marks. There are no Top Picks or profile-completion promotional cards. The Likes tab is separate from Chats: incoming likes remain server-filtered; the empty free state opens Premium and the empty paid state opens discovery. No artificial profiles or counts are added.

The activity toggle is under Profile → settings gear → Mitt konto → Aktivitetsstatus. On shows recent activity to unblocked matches; off requires active server-verified Premium OR the standalone activity-privacy subscription. Without access, it opens a focused page offering just activity privacy or Premium, without changing the saved setting. The server stops applying activity hiding when neither subscription grants access. Existing privacy/presence authorization tests cover this; real-device confirmation remains pending. All earlier manual tests remain unperformed as confirmed again by the owner.
