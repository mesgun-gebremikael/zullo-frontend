# Recovery of saved purchases

The app can safely retry a checkout for which the original account already saved an exact native transaction receipt. This change does not activate billing, create a new purchase, or infer an unknown transaction.

## Authenticated startup and foreground

MainNavigation starts a nonblocking, session-bound KnownPurchaseRecovery runner after the first frame and on foreground resume. It reads only the signed-in account's local pending record. No record or a receiptless record causes no provider synchronization. A saved receipt permits server sync, which reconciles the authenticated account using the provider's authoritative history and idempotent ledger. A successful response refreshes discovery and wallet consumers. Failure retains the record and existing verified state for a later foreground retry.

The runner coalesces repeated foreground requests. Disposal, account generation changes and inactive lifecycle state prevent stale UI events. No native billing or restore API is invoked. The runner leaves local guard clearance to the paywall's exact reconciliation path; starting the app never assumes success based on product, time or balance.

## Paywall reconciliation

Opening Premium, or returning to the foreground while it is open, synchronizes a saved exact receipt before checking its server-owned ledger identity. Verified/refunded status may release the matching local guard. Subscription access still comes only from the server-verified entitlement state.

If the provider sync is unavailable but the server already committed the exact receipt, its authenticated ledger proof may still resolve the guard. A bounded fresh wallet read follows that proof so a newer webhook credit/refund is displayed; failure of that extra read retains the last verified server balance. An offline/unverified result never grants a purchase or silently clears a guard.

## Local attempt identity and compatibility

New local reservations store a cryptographically random 128-bit attempt identity. This is solely a callback identity: a late response cannot attach to or erase a later same-product checkout even if the device clock repeats the exact timestamp. It is persisted with the receipt and compared on conditional writes/removals. Older records without the field keep their existing guard and exact receipt compatibility. A damaged identity fails closed.

This local ID is **not** a transaction binding, server entitlement or proof of payment. It does not solve receiptless interrupted purchases across app termination/devices.

## Remaining activation gates

The pinned RevenueCat Flutter SDK's successful PurchaseResult exposes an exact transaction, but recovery history does not prove which receiptless checkout attempt produced a transaction. Product/time/history differences and mutable customer attributes must not clear that uncertainty. Complete receiptless recovery still needs a supported native/store transaction-binding or durable native transaction-journal design, reviewed with the actual integration and sandbox tests before billing activation.

Test real store success, user cancellation, pending/deferred payments, app termination before/after receipt persistence, offline/provider outage, restore/refund, spent consumables and account/device switching. Owner store configuration, real products/credentials, signing/legal requirements and physical-device checks remain separate. No production deployment, SMTP setup or paid activation is performed here.
