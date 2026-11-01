# UI and incoming likes review

The owner started manual emulator testing and reported Likes showing chat content, misleading empty likes, old styling and layout overflow. Their screenshot shows the Windows checkout 11 commits behind with local edits. The displayed Matches header and brown navigation correspond to older code, so updating the installed test build remains necessary; local edits must be backed up before pulling.

## Corrected in code

- Likes is now a separate page which never reads matches, chat history or the chat repository. Chats no longer fetches incoming likes, so a likes request cannot break chat loading. Explore is its own discovery introduction rather than a second copy of Chats.
- The authenticated `/likes/received/summary` endpoint returns counts and view permission only. Free accounts see the actual locked count; names, IDs and photos remain server-gated. Both summary and identities exclude matched, blocked and invisible users. An ordinary like invalidates the recipient's view via an identity-free SignalR event. Request failures show retry, never a false zero.
- Discovery interest uses large selectable rows, with a separate explicit save. Failed saving retains the open sheet and explains the error. Interest and radius are persisted on the backend. Age range is an account-scoped device preference, restored on restart; it is not a cross-device server preference. Nonfunctional location/global/relaxation controls were removed from this sheet.
- Consistent white application bars, cards and navigation, a light Premium page, existing ZULLO profile cards, distinct Likes/Chats empty states. The profile no longer substitutes a stranger's stock photo when the user's own photo is missing.
- Verification and account deletion/pause remain unimplemented and are labelled unavailable instead of offering dead actions. The marketing-consent switch only changed local state and was removed; this change does not grant marketing permission.

## Verification and limits

Automated checks cover hidden counts without identity leakage, Premium visibility, match/block/invisibility filtering, received-like invalidation over real SignalR/PostgreSQL, recipient rendering, account logout, failed summary responses, editable interest/radius and retry after failed saving, plus the full existing regression suite. Rendered previews were inspected for Likes and discovery settings. Narrow/short layouts and enlarged text are tested.

Store checkout, purchase/restore/refund, push delivery on the owner's devices, all previous registration/profile/chat/blocking test rounds and the updated full navigation still require owner device confirmation. Automated passing tests are not completion of those manual checks. No merge or deployment is performed by this change. Deploy the backend before installing the frontend requiring the summary endpoint.
