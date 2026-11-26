# Push installation ownership

A Firebase token identifies an app installation, not an account. Account generation checks prevent old responses from reaching the UI, but cannot cancel an already dispatched HTTP request. The installation protocol also orders those requests at the server.

## Client intent ordering

`PushInstallationBinding` stores one encrypted JSON value under `zullo.push_installation.v1`: an unpredictable UUIDv4 `installationId` and an increasing integer `version`. The record is device-scoped and survives authentication removal. It is not a bearer credential and grants no account access.

Every claim or unlink reserves and persists its version before sending HTTP. Reservations queue synchronously across service instances. Logout queues its intent before its first await, then clears authentication without waiting for installation storage or network completion. Therefore a later account's claim receives a higher version even when the previous account's unlink arrives late. The registration operation captures its original account generation, including when the same `AuthService` instance is reused for a later login.

Both `/me/device-token` and `/me/device-token/clear` send `installationId` and `version`; claims additionally send `token`. Clear requests retain only the captured old JWT. The server rejects superseded intents. The client does not automatically increase its version to retry a rejected old claim, and never falls back to a legacy versionless request after a storage error.

A missing initial record creates a new random identity. Corrupt or partially missing existing metadata fails closed; it is not silently reset. The native storage operations are not timed out and allowed to continue writing out of order: subsequent reservations wait for the actual previous operation. Authentication and rendering remain independent of this optional push work.

## Message identity and previews

`MessageNotificationHandler` uses push routing IDs only. It checks recipient/relation access, fetches the authorized matched profile, checks account generation again, and rejects a mismatched returned profile. Names, avatars and private message previews in a push payload are ignored. Both cold and warm message opening use this resolver. Foreground banners use the trusted profile and localized generic message copy; the conversation refreshes its contents from the authenticated API.

The corresponding backend must send generic OS notification copy. Client recipient guards alone cannot prevent an operating system from rendering a notification that was already queued before logout or a block.

## Validation and device checks

Tests cover persistent UUID/counter identity, reservation ordering across a stalled write, corrupt/read/write failures, late A claims after B, delayed logout, reuse of an auth service across accounts, and metadata surviving authentication removal. Message tests cover authorization-before-profile lookup, changed accounts, mismatched profiles and rejection of spoofed push previews.

Before release, test two accounts on a physical installation while delaying network requests, then switch accounts and repeat with app backgrounded/terminated. Verify generic OS copy, authorized chat routing and absence of previous-account previews. Native delivery, notification permissions, Focus modes and provider acceptance still require device testing; these tests do not certify guaranteed notification delivery.
