# Profile reading and ZULLO visual refresh

`Bio` already exists in the database with a 1,000-character limit. The editor sends it to `/me/profile`, and the discovery DTO includes it. No new backend table or migration is needed. Existing backend profile-integrity tests cover persistence and explicit clearing of this field.

The public detail view previously displayed placeholder copy instead of `profile.bio`; the photo card's five arrows were decorative. They now open the complete profile, including from the editor preview. `ProfileStory` places the full, selectable presentation in a scrollable surface below the photos. Lifestyle, faith, work/location and interests have separate sections. Empty optional sections and private religion values are omitted. The compact photo overlay does not contain the bio.

Entering preview clears the old cached snapshot, so an edited presentation appears immediately. The editor now labels Save explicitly and uses Edit/Preview segments. Input and save validation match the server's 1,000 UTF-16-unit limit. Saving is still required to publish edits; preview is local.

Discovery's empty state uses warm ivory, rose and a custom vector Z/orbit mark. The conversation mark is also custom vector artwork rather than the former flame/plain bubble combination. Selected navigation states have accessible labels, selected semantics and retained unread indication. The header and navigation have reserved space on the empty screen; compact and enlarged-text content can scroll without being obscured by navigation. Colors shared across these surfaces live in `theme/zullo_palette.dart`; no extra network assets or animation loops are needed.

Log out is in Profile → account settings → Log out. It asks confirmation, clears the session through the existing AuthService, retains the account and returns to Welcome with root history cleared. Cancellation stays on the account screen. Generation checks prevent a late logout from replacing navigation belonging to another session. The swipe header no longer exposes logout.

Validation includes long presentation scrolling, separate lifestyle content, refreshed editor preview and navigation to the full profile, compact/enlarged-text editor and navigation, and confirmed/cancelled logout including disposal during storage work. Test-only PNG capture is opt-in with `ZULLO_CAPTURE_DIR`; it uses local fonts for visual inspection, not a real phone screenshot. Android and iOS native build checks run in CI; real-device appearance, text/picker behavior and actual Cloudinary uploads remain manual checks from APP_REVIEW.md.

This refresh covers the reported discovery, navigation, reading, editing and account entry surfaces. It is not a complete redesign of every screen or proof of production device performance. Deploying this frontend requires no additional backend update beyond the already merged APIs.
