# Location, chat profiles, conversation prompts and visual correction

## Delivery and scope

Deploy the matching backend migration `DiscoveryLocationAndPrompts` before this frontend. It adds private discovery preferences/current-location metadata and the optional conversation prompt fields. The backend and frontend PRs depend on each other; the earlier visual PR is already merged. No server geocoding key or background tracking service is needed. Keep existing Firebase/Cloudinary credentials server-side.

The rejected ivory/muted rose palette is replaced with white, cool neutral gray and a bright pink accent. `zulloTheme()` centralizes the actual app theme, including white popup/dialog/bottom-sheet backgrounds. The empty discovery copy is rewritten and contains no return-later message. Chat menus and report/block dialogs use the same neutral surfaces. Block asks confirmation before the existing block request. This is not a claim that every unrelated screen has been rewritten.

## Matched profile from chat

Tapping the chat name/avatar fetches the current profile from the authenticated `/profiles/{userId}` endpoint. It requires an existing match and rejects either-direction blocking, closure and unmatching. The DTO includes all profile photos, bio and the conversation prompt but no coordinates or private current-location metadata. The gallery swipes horizontally, shows its position, and handles failed image loading. Existing relation-generation guards hide the view after block/unmatch and reject late account data.

## Optional conversation starters

Create/edit profile offers a question from a shared five-item catalog plus an answer up to 250 UTF-16 units. Both are saved together, included in private resumable drafts, and shown separately in the full profile. Unsupported/incomplete public question/answer pairs are rejected. Clearing both removes the answer. Bio remains independent and limited to 1,000 units. Optional setup steps show an explicit Skip action; a half-finished unanswered prompt is cleared on skip. Required identity/age/photos remain required. The intention step uses selectable cards, preserving existing values rather than changing the meaning of old profiles. Prompts suggest conversation topics; they do not send messages automatically.

## Foreground location and discovery

Profile → account settings → Place & discovery shows the saved discovery place. Updating it is an explicit user action that requests the OS's when-in-use permission. Approximate location is supported; unusably inaccurate or timed-out fixes show a readable error. Native geocoding supplies city/country when available, with a neutral current-place label on failure. Home city remains a separate user-entered profile field.

After activation, the app checks on foreground/resume and periodically while foreground, throttled to five minutes. It does not request Always/background permission, create a background location mode or store a journey history. Late results after account switch/background do not update another session. The server returns whether movement is meaningful (at least 1 km or first fix), so small GPS fluctuations do not repeatedly replace the discovery feed. Refresh waits while a card is being dragged/animated. Network/GPS work runs independently of first screen rendering.

The maximum distance, age and interested-in choices save atomically. Ages are server-backed with an account-scoped offline copy; pre-existing local ages are retained until an authoritative age choice has been saved. Separate distance/age expansion switches default off. Only when strict results are empty can enabled fallback show nearby people (radius + 25 km or 1.5×, whichever is larger, capped at 450 km), and/or up to 5 years beyond the preferred ages, always within 18–100. It never relaxes gender preference, visibility, block, pause/closure or incognito access. Response flags/full profile explain expanded candidates. No fake profiles or undeclared automatic filter changes are added.

## Validation and manual checks

Automated coverage includes authenticated gallery access/privacy, gallery swipe from chat, neutral safety menus/cancel, prompt persistence/clearing/skip, invalid settings, account-isolated and foreground-only GPS writes, throttling, strict-vs-expanded search and actual travel changing the discovery centre. PostgreSQL checks exercise real migrations/rollback, location JSON/API/SQL behavior and existing concurrent/load/account/photo flows.

CI builds Android and iOS, with the native dependency lock reviewed after plugin resolution. These builds do not prove device permission behavior. Still verify on real Android/iPhone: first allow, deny, approximate permission, disabled GPS, offline geocoder, foreground/resume and travel; photo galleries with real Cloudinary media; save/resume/edit of prompts. In Android Emulator, set a simulated location in Extended controls → Location; in iOS Simulator, select a simulated location through Features → Location. Release/profile device performance, store signing, payments and live provider verification remain separate from these checks.
