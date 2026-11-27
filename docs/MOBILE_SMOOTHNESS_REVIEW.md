# Mobile responsiveness review — 26 November 2026

Reference: the owner's 8.44-second, 60fps Instagram recording, switching rapidly between retained home, messages and profile tabs. The reference establishes interaction expectations; it is not a benchmark of ZULLO or a promise of identical device frame timings.

## Concrete changes

- Retain tab state with IndexedStack, pause hidden/background tickers and exclude hidden focus; isolate tab repainting. Ignore same-tab taps and unchanged unread values instead of rebuilding the discovery screen for chat acknowledgements.
- Chat list updates ignore thread-only repository events. Native platform routes restore standard iOS chat transitions and interactive back navigation.
- Profile/wallet requests coalesce; stale-account responses cannot overwrite the active account. Editing refresh retains visible profile content. Loading failures display a readable retry action.
- Swipe animation now listens to its controller every frame. Network acceptance runs concurrently with movement; a synchronous reservation prevents duplicate taps/paid Superlikes. Success advances only after server acceptance; failure restores the same profile. Disposal cancels the animation safely. Reduce-motion is respected.
- Swipe card image/content widgets remain stable during frame/gesture transforms. CurveTween avoids adding a new persistent controller-status listener on every gesture.
- Pending feed responses are invalidated by a swipe and refreshes are deferred until it completes. Rewind and new swipe cannot overlap. A token read completing after account change cannot submit a swipe for the old account.
- Paywall initial loading is distinguished from unavailable prices; selected actions show progress immediately and duplicate actions are blocked. Store identity preparation rechecks the account before launching purchase. Server rights, prices, transaction ownership and uncertain purchase guards remain authoritative.
- Backend review and measured request reductions are documented in the companion backend's docs/MOBILE_PERFORMANCE_REVIEW.md.

## Verification and limits

Regression tests cover in-flight network animation, rapid taps, request failure, disposal, feed replacement, account switches, retained tabs, ticker lifecycle, selective updates and paywall loading/purchase races. The complete test/analyzer and native build results must be recorded on the final commit, not inferred from a prior revision.

Before launch, run profile-mode on a representative iPhone and Android phone. Record UI/raster frame timings while swiping repeatedly and switching tabs; inspect slow frames using Flutter DevTools. At 60Hz the frame budget is about16.7ms; at120Hz about8.3ms. Test cold/warm image loading, slow/offline requests, background/resume, dynamic text, reduced motion and native back gestures. Emulator/debug performance alone cannot certify physical-device smoothness.

Keep real billing disabled until actual App Store/Google Play/RevenueCat products, legal links, signing, sandbox receipts/restores/refunds and interrupted checkout recovery are verified. A native store sheet's loading time depends on store/network availability; no fake payment success, invented price or cleared uncertain charge is used to make it appear faster.

## Deferred by owner

Resend/domain/SMTP setup is intentionally deferred. See docs/PROJECT_MEMORY.md and the backend docs/RESEND_SETUP.md. Existing login remains available; new email signup requires real delivery and remains fail-closed without it. No production deployment, billing activation or domain purchase is part of this review.
