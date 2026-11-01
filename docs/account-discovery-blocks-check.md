# Account, discovery and block lifecycle

Deploy the companion backend first (GET /me/account, GET /blocks, DELETE /blocks/{userId}, RelationChanged). No schema migration is required. The frontend keeps the latest error state if loading fails; a failed list request does not mean the list is empty.

## Manual check with two accounts

1. Sign into A and B on separate devices/emulators. In Mitt konto, confirm each shows its own email. Reopen to verify it is loaded from the account.
2. Open Swipa → Inställningar → Intresserad av, choose Män, Kvinnor or Alla and press the check mark. Verify the new feed fits the saved choice. Reopen settings and restart the app to verify persistence.
3. Match A and B and send a message. With B's chat open, block B from A's chat menu. Both chat lists and open conversation must remove the pair, and the pair must be absent from likes and discovery. Existing message endpoints must deny access in both directions.
4. On A, open Mitt konto → Blockerade profiler. B is listed. B's list must not disclose A's outgoing block. Cancel Avblockera once to verify it changes nothing, then confirm it. Close/reopen the list: B is absent.
5. The old match/chat must not return. When discovery preferences, visibility, age and distance permit, the pair can appear in Swipa again. One new like is insufficient; two fresh reciprocal likes create a new match with an empty chat. New messages should then work.
6. Repeat with both users blocking each other. Removing A's block must not remove B's. They remain hidden until both remove their own block.
7. Repeat a block while B is backgrounded/disconnected. Resume/reconnect B: the server's current match list must evict the old chat and caches. If a new match was created while a client was away, its changed match timestamp invalidates the previous cached thread.

## Implementation notes

The server stores the discovery preference on the profile; frontend saves it along with existing filter settings, clears prefetched cards and reloads discovery. RelationChanged invalidates local conversation/profile/card state and reloads lists. Stale list/feed/history responses are rejected. History invalidation is scoped to the affected conversation, so blocking one person does not close a different chat.

Block removes both directions' previous likes/skips and the match. Unblock removes only the caller's block and clears the pair's old messages, allowing a fresh match/conversation; unrelated messages remain untouched. List reconciliation uses matchCreatedAtUtc to handle missed socket events. Live invalidation requires a connected client; disconnected clients reconcile when they reconnect/resume.
