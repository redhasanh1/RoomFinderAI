# LEARN.md — RoomFinderAI design log

Running notes on bugs we hit, what worked, what didn't, and what to remember next time. Newest entries on top.

---

## 2026-05-17 — AI Negotiator parsed "6k to 7k" as $6,000 instead of $7,000

User typed "6k to 7k" as their budget. The AI's natural-language reply correctly echoed "$6000 to $7000" (so the LLM understood the range), but the structured `criteria.price` from `/api/chat` came back as just `6000`. The frontend stored that as `userNeeds.maxPrice`, the Supabase search ran `lte('price', 6000)`, and the actual matching house at $6,375 fell off the "exact" results into the "similar listings" bucket with a useless "increase your budget above $6000" suggestion.

Two failures stacked: OpenAI's structured extraction picked the lower bound when it should have used the upper, AND the manual fallback regex at `ai-chat.js:462` only matched `\d{1,5}` — no "k" suffix and no range awareness, so it would have hit the same wall.

**Fix (`ai-chat.js`):**
- Added `extractPriceFromMessage(message)` — a range-aware extractor that normalizes the message (strips `$` and `,`, lowercases), tries a range regex first (`X to/-/and Y` with optional `k` on either side), returns the MAX of that range. Falls back to single-value parsing with the same `k` suffix support.
- Updated `extractManually` to use it (replaces the old narrow regex).
- Augmented the OpenAI happy path: even when `/api/chat` returns a `criteria.price`, also run `extractPriceFromMessage(message)` on the raw user text — if the local extractor finds a higher number, use it. Defends against OpenAI under-grabbing on ranges.

**Heuristic decision:** for a range like "5 to 7k" we always take the UPPER bound as max price. That matches normal usage — when someone says "5-7k" they mean "I'm willing to go up to 7k," not "filter strictly to 5k and below."

**Pattern to remember:** for chat-driven filtering, never let a single number from the LLM override what the user's raw message says. Run a structured local pass over the message text alongside the LLM extraction and take the bound that's friendlier to the user (higher max, lower min). LLMs hallucinate bounds; regex doesn't.

---

## 2026-05-17 — Live chat delivery via Supabase Realtime broadcast (sub-100ms)

Even with the postgres_changes subscription + 5s delta poll, messages between two open chats lagged enough that the user had to click back into the conversation to see them. `postgres_changes` watches the WAL, parses every INSERT, and evaluates RLS per subscriber — that's 500ms-2s of overhead per message, every time. The poll was the floor at 5s. Neither felt instant.

**Switched to Supabase Realtime `broadcast` mode** for live delivery alongside (not replacing) the existing paths:

- **Send-side:** after the DB INSERT in both `sendTextMessage` (line 2605) and the fallback `sendChatMessage` (line 5788), publish on `supabase.channel('chat-{conversationId}').send({ type: 'broadcast', event: 'new_message', payload: {...} })`. Fire-and-forget; the DB INSERT remains the source of truth so a broadcast failure is non-fatal.
- **Receive-side:** at the top of `loadMessages` (line 3455), unsubscribe from any prior chat channel, then subscribe to the current conversation's `chat-{id}` broadcast channel. Handler appends a `.message.received` node and bumps `lastSeenMessageAt`. Stored on `window.__currentChatChannel` for the next subscribe to clean up.

Latency went from 500ms-2s (postgres_changes) to ~30-150ms (direct WebSocket pub-sub, no DB involvement on the receive). The DB write happens in parallel for persistence; old messages still load via `SELECT` on conversation open.

**Three delivery paths now coexist, all dedup'd by `lastSeenMessageAt`:**
1. `broadcast` — sub-100ms, fires when both clients have the same chat open
2. `postgres_changes` (existing) — fallback if broadcast isn't subscribed yet (e.g. timing race during chat open)
3. 5s delta poll (existing) — safety net if Realtime is completely down

**Why broadcast over postgres_changes for chat:** postgres_changes does heavy work (WAL parsing, RLS eval per subscriber) on every message. Broadcast is a thin pub-sub layer — no DB, no per-row policy check, scales linearly with active rooms instead of with total message volume. Persistence is still in Postgres; broadcast is purely the delivery channel. This is the recommended Supabase pattern for chat.

**Cost / infra impact:** zero. Same Supabase plan, same DB, no new services.

---

## 2026-05-17 — Password reset succeeded, then login failed with "Email not confirmed"

After `/api/reset-password` returned 200 and the green "Password Reset Successfully" page appeared, users with `auth.users.email_confirmed_at = NULL` couldn't log in. Supabase Auth's `signInWithPassword` rejects unconfirmed accounts before checking the password at all.

The mismatch lived in `backend/server.js:3727` — the admin update call only passed `{ password: newPassword }`. So the new password landed but the email-confirmation flag stayed null. Especially common for the 11 backfilled orphans from this morning's `auth.users → profiles` trigger (they were in auth.users since 2025-08-05 with `email_confirmed_at` perpetually null).

**Fix:**
- Pass `email_confirm: true` alongside the password to `supabase.auth.admin.updateUserById`. Supabase Auth treats this as "force-mark the user's current email as confirmed" — semantically identical to them clicking a confirmation link, which is exactly what verifying the 6-digit reset code amounts to.
- Restructured the reset flow so `profiles.password` is **always** synced after the auth.users update too. The old code's if/else made the two stores exclusive: if the user was in auth.users, the profile-password column was never updated. That broke login's fallback bcrypt path if Supabase Auth ever became unreachable. Now the sync is unconditional, with severity tiered: when the user is auth-less, profile-sync failure is a 500 (it's the only store); when auth.users is the authoritative path, sync failure is a `console.warn` and the request still returns success.

**Pattern to remember:** anywhere a password-reset (or magic-link, or email-verify-by-code) flow proves the user owns an email by some out-of-band method, the handler should **also** set the email-confirmed flag at write time. Forgetting it leaves the user technically authenticatable but bureaucratically locked out — and the failure is invisible from the reset side, only surfacing on the next login attempt.

**One more sanity rule from this session:** for ANY auth flow that has a "you just confirmed something" moment, the test isn't "did the write succeed" — it's "can the user actually log in now?" Always do the end-to-end login as part of the reset's verification.

---

## 2026-05-17 — `delivered` ≠ inboxed: Yahoo silently drops resend emails

After the sender swap (Track 1 from the prior fix) the *first* reset email landed and was opened (Brevo `opened` event confirmed). The Resend button fired a fresh `POST /api/send-reset-code` within two minutes — Brevo logged a clean `requests`→`delivered` pair, the browser showed "New code sent" — and the email never reached Yahoo inbox or spam. Hasan confirmed both folders.

`delivered` is an SMTP-level event: Yahoo's edge server replied `250 OK` to the `DATA` command and the message was accepted into Yahoo's pipeline. After that, Yahoo's content/policy filters can silently discard before inbox or spam touch the message. Two compounding factors here:

1. **SPF mismatch.** `From: humblewoslayer@gmail.com` over Brevo's relays. The SPF record at `gmail.com` authorizes only Google's IPs as senders for `gmail.com`, so Yahoo sees SPF-fail and slides toward quarantine.
2. **Near-duplicate within 2 minutes.** Identical sender + identical subject (`"Reset your RoomFinderAI password"`) to the same recipient. Yahoo's dedup-style filter clamps down harder on the second message.

**Real fix** is Track 2 — a custom sender domain (`mail.roomfinderai.com`) with SPF/DKIM/DMARC at the registrar. Hasan didn't have DNS access in this session so deferred. The two-line code stopgap shipped today:

- **Subject variation per send** in `sendPasswordResetEmail()` (`backend/server.js:1768`): the subject now appends a `(H:MM AM/PM)` timestamp, so two consecutive resets have distinct subjects. Defeats both filter-side dedup and inbox-side threading.
- **60s client cooldown on the Resend button** (`forgot-password.html:365+`): after a successful resend, the button locks for 60 seconds with a visible countdown (`Resend code in 60s` → … → re-enable). Prevents users from triggering rapid duplicates and keeps each send at a gap Yahoo treats as fresh. On error the button restores immediately so retries aren't blocked.

**Pattern to remember:** Brevo's API returning 200 says the request was accepted. Brevo's `requests`+`delivered` event log says the recipient SMTP server accepted at protocol level. **Neither says "the user sees this in their inbox."** When users report missing mail despite green Brevo events, the answer is almost always at the recipient's content filter, and the diagnostic is: did delivery happen? (yes — Brevo `delivered`). Then the problem is post-delivery quarantine — there's nothing to fix on the sender side except reputation (sender domain + DKIM + rate hygiene). For high-stakes mail (password resets), always own your sender domain.

---

## 2026-05-17 — Brevo silently rejects sends when sender isn't verified

After regenerating the Brevo API key and redeploying, `/api/send-reset-code` returned 200 `"Reset code sent to your email"` and the handler logs said `✅ Password reset email sent successfully`. Inbox stayed empty. The handler looks like it succeeded, but the email never left Brevo.

The truth was in `GET https://api.brevo.com/v3/smtp/statistics/events?email=…&limit=20`. Every send logged a `requests` event followed immediately by an `error` event:

> "Sending has been rejected because the sender you used **wilmahenning01@gmail.com is not valid**. Validate your sender or authenticate your domain"

So the API accepted the request (hence the 200), then Brevo's send pipeline rejected it because `EMAIL_CONFIG.SENDER_EMAIL` was a `@gmail.com` address that wasn't on the active Brevo account's verified-senders list. The new account (under `humblewoslayer@gmail.com`) had its own sender (also `humblewoslayer@gmail.com`, id=1, name `roomfinderai`) — but no longer wilma. The dead key from before this had probably been issued under a different Brevo account that still had wilma verified.

**Fix:** changed `backend/server.js:36-45` `SENDER_EMAIL` and `BACKUP_RECIPIENT` from `wilmahenning01@gmail.com` to `humblewoslayer@gmail.com` (the verified sender on the active account). One commit, one Railway redeploy, sends started getting `delivered` events instead of `error`.

**Pattern to remember:** when Brevo returns 200 to the API call but no email arrives, **don't trust the request-side response** — hit the **events log** endpoint (`/v3/smtp/statistics/events`). The events log distinguishes between "the API accepted your request" (`requests`), "Brevo's pipeline rejected it" (`error`), "the recipient mail server got it" (`delivered`), "they bounced it" (`bounced`), and so on. Status 200 on `POST /v3/smtp/email` is a *queueing* confirmation, not a *delivery* confirmation. We almost re-broke the whole investigation by trusting the 200.

Also: `GET /v3/senders` lists the verified senders for the current key's account. Always check it before assuming a hard-coded sender is valid — it's a one-call read that tells you exactly which addresses Brevo will accept.

---

## 2026-05-17 — auth.users / public.profiles data drift (orphan signups)

Follow-up on the forgot-password investigation: when Hasan saw "Email already registered" for `cryptocoins0@yahoo.com` but the same email returned the silent-200 from `/api/send-reset-code`, it pointed at a deeper data-model split.

**Audit (via service-role direct SQL through the management API):**
- `auth.users`: 16 rows
- `public.users`: 1 row (basically unused)
- `public.profiles`: 10 rows
- `auth.users` without a matching `public.profiles` by email: **11 of 16** — the orphan rate was huge, not a one-off.

The orphans are users whose signup landed in Supabase Auth but never reached `public.profiles` — possibly mid-flight signup failures, or signups via a path that didn't include the profile insert. Every one of them gets locked out: signup blocks ("already registered"), forgot-password silently 200s ("if an account exists…"), no recovery.

**Permanent fix (`database/migrations/auth_user_creates_profile.sql`):** added a trigger on `auth.users AFTER INSERT` that inserts a matching `public.profiles` row (`SECURITY DEFINER`, `WHERE NOT EXISTS` to stay idempotent). And a one-time backfill: every existing orphan got a profile row inserted, dropping the orphan count from 11 → 0 and surfacing `cryptocoins0@yahoo.com` into `profiles` so forgot-password can find it.

**Why `profile.user_id` is left NULL on auto-created rows:** `profiles.user_id` is a FK to `public.users.id`, but `public.users` is nearly empty and we can't safely fabricate rows in it from a trigger without bigger schema decisions. The `/api/send-reset-code` handler only matches by email, so a null user_id doesn't break recovery. The data-model cleanup (consolidating to one users table) is a separate bigger task — flagging as a follow-up.

**One detail to remember:** when sending DDL through the Supabase Management API (`POST /v1/projects/{ref}/database/query`), `$$ ... $$` function bodies inside a PowerShell **double-quoted** here-string get partially eaten by shell variable expansion. Use `@' ... '@` (single-quoted here-string) and Postgres `$func$ ... $func$` tagged dollar quotes to be safe.

---

## 2026-05-17 — Forgot-password emails not arriving (TWO root causes stacked)

A user (Hasan testing with `cryptocoins0@yahoo.com`) hit "Send Reset Code", UI said "We've sent a 6-digit code to ..." but nothing ever arrived. Diagnosis required hitting live infra; both findings would have stalled email delivery on their own.

**Cause 1 — Email not registered.** Queried `profiles?email=eq.cryptocoins0@yahoo.com` via the publishable key: zero rows. The handler at `backend/server.js:3528-3611` looks up the email in `profiles` then in-memory `users`, and when neither has it, returns a *silent 200* with the anti-enumeration message `"If an account exists with this email, a reset code will be sent."` — no code is generated, no Brevo call is made. The frontend at `forgot-password.html:236-279` treats any 200 as success and advances to the "Enter Reset Code" step. So unregistered emails got a confidently-successful UI with zero email actually queued.

**Cause 2 — Brevo API key disabled on Railway.** Pulled the live `BREVO_API_KEY` from the Railway production env via the project token and hit `https://api.brevo.com/v3/account` with it: Brevo returned **401 "API Key is not enabled"**. So even if a registered user had requested a reset, the `sendPasswordResetEmail` axios call at `backend/server.js:1819` would have failed and the handler would have returned 500. The frontend would have shown an error toast — different failure mode, same outcome (no email).

**Fix code-side (committed):**
- Softened the no-user 200 response copy and matching `forgot-password.html` description so users who typo'd or aren't signed up don't keep staring at their inbox. Still returns 200 (no enumeration leak) but the body and the page both say "If this email is registered..." with a nudge to check spam or signup state.
- Added `console.log('🔕 send-reset-code: no profile/user for email, returning silent 200:', email)` so the previously-invisible silent-200 path now shows up in Railway logs when triaging "no email arrived."

**Fix infra-side (NOT code, requires Brevo dashboard):**
- Re-enable the disabled `xkeysib-1d…` API key, OR generate a new SMTP API key and replace the `BREVO_API_KEY` value on Railway production. Whoever does it should also confirm `wilmahenning01@gmail.com` (the hard-coded `EMAIL_CONFIG.SENDER_EMAIL` at `backend/server.js:39`) is still verified in Brevo → Senders & IP, otherwise sends will 4xx with a sender-verification error.
- The startup probe `testBrevoApiKey()` at `backend/server.js:87-118` will log `✅ Brevo API key is valid` (with account email) on healthy startup, or `🚨 BREVO_API_KEY appears to be invalid or expired` if it's still broken. Look for that line after redeploy to confirm.

**Yahoo footnote.** Even with a healthy key, transactional mail to `@yahoo.com` lands in spam aggressively unless the sender domain has SPF/DKIM/DMARC configured. If real users on Yahoo continue not receiving emails, the next move is to add a verified sender domain in Brevo with DNS records — not another code change.

---

## 2026-05-17 — Both bubble sides landed on the right + Realtime alone wasn't reliable

After the first chat fix, Hasan reported: "the other person's message shows on the right side as well." Two layered bugs.

**Bug A — `margin-left/right: auto` doesn't right/left-align shrink-to-fit blocks.** `.message.sent` had `margin-left: auto` and `.message.received` had `margin-right: auto`. Auto margins absorb remaining space only when an element has a *defined* width. The message bubbles have `max-width: 80%` but no `width` — so the element's actual width is shrink-to-fit, and `auto` margins resolve to 0. Net effect: both sides hugged the start edge. **Fix:** made `.chat-messages` `display: flex; flex-direction: column;` and switched the bubbles to `align-self: flex-end` / `flex-start`. Bonus: also tightened bubble radius/padding for a more iMessage-like silhouette.

**Bug B — case-sensitive sender comparison.** Both `loadMessages` and the Realtime handler did `message.sender_email === currentUser.email`. Stored email casing drifts (signup vs OAuth vs legacy rows), so a `User@Foo.com` row would never match the current `user@foo.com` user, and every message ended up classified as the "other party." **Fix:** `.toLowerCase()` on both sides of the comparison everywhere it appears (text-message render, file-message render, Realtime handler, delta poll).

**Bug C — Realtime alone left users in the cold when the subscription silently failed.** Added a **delta-poll fallback**: a 5s `setInterval` that queries `messages WHERE conversation_id = current AND created_at > lastSeenMessageAt`. The watermark is seeded by `loadMessages` and advanced by both the Realtime handler and the poll, so the two paths never double-render. Most polls touch zero rows (cheap). The poll skips when `document.hidden` so background tabs don't drain battery. If Realtime delivers first, the poll finds nothing. If Realtime breaks, the poll catches up within 5s.

**Known limitation to revisit:** the incremental append paths (Realtime + poll) only render text messages. File messages still wait for the next `loadMessages` cycle. Worth DRY-ing into a shared `appendMessageToChat(message, currentUser)` helper that mirrors `loadMessages`'s render logic for `message_type:'file'` once it matters.

---

## 2026-05-17 — Chat live receive, files button gated to landlord, white receiver bubbles

Three small bugs piled into the docked chat:

1. **Receiver messages didn't appear until refresh.** The Realtime `messageChannel` subscription (listings.html:2768) correctly detected when a new message belonged to the open conversation, but its handler called `loadMessages(currentConversationId)` (full clear + reload) AND had a dead `console.log('🚀 Adding message instantly to UI')` line under which the actual DOM append was never written. The full-reload path raced against the send handler's optimistic append and frequently lost the new message. **Fix:** in the Realtime handler, build a single `.message.received` DOM node from the payload and `appendChild` it (skipping when `payload.new.sender_email === currentUser.email` to avoid double-rendering the user's own send). No more `loadMessages` from realtime.

2. **`📎 Files` button only visible to listing owners.** `startConversation()` had an explicit `if (isCurrentUserLandlord) { ...remove hidden } else { ...add hidden }` gate (lines ~3354-3364). Worse, `openConversationInModal()` — the path that fires when you click an existing conversation in the panel — never touched the button at all, so its visibility leaked across sessions. **Fix:** unconditionally `classList.remove('hidden')` on `fileUploadBtn` in both entry points. The upload pipeline behind it (file picker → Supabase Storage `chat-documents` bucket → message row with `message_type:'file'`) was already wired end-to-end, just gated for no good reason.

3. **Receiver bubbles were white with a grey border.** Reads as a generic chat app. **Fix:** changed `.message.received` in `frontend/modules/css/components.css` from `background:white; border:1px solid gray-200` to `background:#e9e9eb` (iMessage iOS grey) with the border dropped entirely. Sender bubble (`.message.sent`) untouched — it was already correctly colored.

**Pattern to remember:** when you see a dead `console.log(...)` like "🚀 Adding message instantly to UI" with no actual DOM/state code under it, that's almost always an abandoned implementation. The surrounding fallback (`loadMessages` here) is what's actually running and probably wasn't designed to carry the full load — re-evaluate before adding more around it.

---

## 2026-05-17 — Chat window covered the whole screen instead of docking bottom-right

**Symptom:** opening a conversation on `listings.html` slammed a fullscreen modal with a blurred backdrop over the listings. Users couldn't see the listing they were chatting about.

**Root cause:** `.chat-modal` and the generic `.modal` selector were grouped in `modules/css/components.css` (`.modal, .chat-modal { position:fixed; left:0; top:0; width:100%; height:100%; background:rgba(0,0,0,0.5); backdrop-filter:blur(4px); }`). They share *most* properties — but they shouldn't share *positioning*. Same for `.modal-content, .chat-modal-content` in the responsive media queries.

**Fix (`frontend/modules/css/components.css`):**
- Unbundled `.modal` from `.chat-modal` in the base rule. `.modal` still goes fullscreen with backdrop (used by listing-details / generic dialogs). `.chat-modal` is now a bottom-right anchored bubble: `position:fixed; right:1rem; bottom:1rem; pointer-events:none` with no backdrop and no blur.
- `.chat-modal-content` is a fixed 360 × 70vh box (max 560px tall, 360px min), flex-column for header / messages / input. Override rules inside `.chat-modal-content` strip the inner `.chat-messages` `min-height: 300px; max-height: 400px` so the messages area flexes within the bubble.
- `.chat-header` now gets a small gradient bar (`#667eea → #764ba2`) like Messenger to give it a clear top affordance.
- Mobile (`max-width: 480px`): bubble docks to the bottom edge with 0.5rem side margins so users can still see the listings above.

**Side-effect to watch:** other modals using `.modal` keep their previous behavior — the unbundling didn't touch their rules. If any code was relying on `.chat-modal` having the same fullscreen overlay as `.modal` (e.g., to click outside to close), that click-outside path now does nothing because there's no backdrop element to click. The × close button still works.

---

## 2026-05-17 — listings.html polled `loadUserConversations` every 3s, hammering Supabase

**Symptom:** browser console on `listings.html` flooded with `📬 loadUserConversations called` / `Querying ALL conversations first...` / `Checking conv:` lines every 3 seconds. On mobile this would drain battery; on free-tier Supabase this would torch the rate limit.

**Root cause stack (worst → least):**
1. A `setInterval(fn, 3000)` declared as a "polling fallback for real-time" — but the conditional check was abandoned with a comment "messageChannel is not in scope here, so we'll just start polling as fallback." It started polling **unconditionally**, after 10s, even though a healthy Supabase Realtime `panelChannel` subscription was set up right above it. Result: realtime + polling running in parallel.
2. `loadUserConversations` issued an extra SELECT of "ALL conversations in DB" on every call (purely a `console.log` debugging aid, never used by the function).
3. Per-iteration `console.log` for "Checking conv:", "Including conversation:", "Filtering conversations:" inside the filter loop — multiplied per conversation per poll.

**Fix (`frontend/listings.html`):**
- Removed the debug "all conversations" SELECT (one fewer query per call).
- Stripped the per-iteration logs (kept only error logs).
- In the Realtime `.subscribe(status)` callback, set `window.__panelRealtimeOk = true` on `SUBSCRIBED`. Polling start now gates on that flag — **if realtime is healthy, polling never runs**.
- If polling does run (true fallback only), interval is now **30s instead of 3s**, and the interval body bails out early when `document.hidden` (tab in background) so mobile users don't burn battery.

**Numbers (per user with one conversation):**
- Before: ~4 Supabase queries every 3s = ~80 queries/minute, never paused.
- After (realtime healthy): ~0 queries unless an event actually fires.
- After (realtime down, fallback engaged): ~4 queries every 30s = ~8 queries/minute, **paused when tab is hidden**. 10× reduction even in the worst case.

**Bigger follow-up to keep in mind:** the per-conversation unread-count loop still makes 2 queries per conversation (one for `conversation_reads`, one for `count(*) FROM messages`). For users with N conversations that's 2N round trips. Worth converting to a single aggregate query (a Postgres function returning `(conversation_id, unread_count)` rows) once N gets uncomfortable.

---

## 2026-05-17 — Heart icons didn't restore the "favorited" state on listings.html

**Symptom:** clicking the heart on a listing card saved it (visible on `favorites.html` / profile), but reloading `listings.html` showed every heart back in the outline/gray state — favorites weren't visually restored on revisit.

**Root cause:** `loadFavoriteStates()` was calling `GET /api/favorites/${currentUser.id}` — an endpoint that doesn't exist. The backend has `GET /api/favorites?userEmail=...` (returns full listing rows for every favorite, expensive) and `POST /api/favorites/check` (returns just `{listing_id: bool}` for a set of IDs, cheap), but no `/api/favorites/:userId` route. So every `loadFavoriteStates` call silently 404'd. Separately, even when working, the function was only called from the auth-init code path; clicking the page's Refresh button re-rendered cards without re-running the state restore.

**Fix (in `frontend/listings.html`):**
1. Rewrote `loadFavoriteStates` to use `POST /api/favorites/check`. Collects the listing IDs of currently rendered `.favorite-btn` elements, sends them in one POST with `userEmail`, gets back a `{listingId: boolean}` map, flips the `data-favorited` attribute on matches. One round trip, one indexed SELECT on the backend, zero per-listing follow-up queries.
2. Call `loadFavoriteStates()` from inside `displayListings()` after the cards render, in addition to the existing auth-init call. Fire-and-forget (not awaited), so it runs alongside the map update.

**Why `/api/favorites/check` over `GET /api/favorites`:** the GET path loops `data.length` Supabase queries to fetch full listing details for every favorite — even ones not currently on screen. For our use case (just paint hearts on what's visible), `check` is dramatically less work both client- and server-side.

---

## 2026-05-17 — Map View only populated after a manual Refresh click

**Symptom:** even with the coords cache fully populated, the map showed zero pinpoints on first load of listings.html. Markers only appeared after the user clicked the Refresh button.

**Root cause:** `displayListings()` calls `updateMap(listings)` immediately after fetching, but at that moment `mapContainer` still has the `hidden` class (the page boots in Grid View). `initMap()` short-circuits when the container is hidden (line ~972), so `updateMap` runs against a non-initialized map. Then `setViewMode('map')` (the Map View toggle handler) tries `window.currentListings` to populate markers after the container becomes visible — but **nothing in the code ever assigns to `window.currentListings`**, so that fallback was effectively dead. Clicking Refresh ran `displayListings(true)` *with the map container now visible*, which is why it worked then and only then.

**Fix (in `frontend/listings.html`):**
1. In `displayListings()`, assign `window.currentListings = listings` right after the fetch succeeds. This makes the cached-listings fast path actually function.
2. In the `setViewMode('map')` map-init callback, if `window.currentListings` is empty or missing, call `fetchListings()` inline before `updateMap()`. Belt-and-suspenders so the map populates even if the user toggles to Map View before the initial grid render finishes.

**Smell to remember:** `if (window.foo)` reads with no corresponding writes are a classic dead-fallback pattern. Grep for the read AND the write before trusting a "lazy init via global" path.

---

## 2026-05-17 — Google Maps Geocoding gated by billing; added Nominatim fallback

**Symptom (follow-up to the map fix below):** after applying the migration and wiring the service role key into Railway, `/api/geocode/batch` returned `REQUEST_DENIED` for every listing. Hitting the Google Geocoding API directly with our `GOOGLE_API_KEY` returned `error_message: "You must enable Billing on the Google Cloud Project"`. The key is valid, but the GCP project that owns it never had billing enabled. (The free tier is generous — 40k geocodes/month — but Google still requires a billing account on file.)

**Fix:** Rather than block on Hasan enabling billing (and dealing with a Google Cloud dashboard), `/api/geocode/batch` now tries Google first and **stickily falls back to Nominatim for the rest of the batch** the moment Google says REQUEST_DENIED with "billing" in the error. Nominatim is throttled to 1 req/s per their usage policy, enforced by the endpoint. Each response item carries a `source` field (`google` / `nominatim` / `cache`) so the caller can see which path served it.

**Numbers from the live prewarm (Nominatim path):** 9 listings cold = 9.87s; same 9 listings warm = 0.85s (8 `cache`, 1 `no_results` — that listing has bad address data and will keep failing until the user fixes it). Subsequent map loads cost one Supabase SELECT and zero upstream calls.

**Follow-ups not done:**
- Enable billing on the GCP project owning `GOOGLE_API_KEY` to flip the fast path back on (Nominatim works but is slower for first-time geocodes — fine at current volume, will hurt as listings grow).
- Viewport bounding-box query is still worth doing once listings > ~100 (the partial index from the migration already supports it).

---

## 2026-05-17 — Map on listings.html showed zero markers

**Symptom:** `https://www.roomfinderai.com/listings.html` rendered the Leaflet map but no listings appeared on it.

**Root cause:** the `listings` table had no `latitude`/`longitude` columns, so `fetchListings()` couldn't return coords. To compensate, `updateMap()` called `geocodeLocation(addr)` for every listing — which hit `nominatim.openstreetmap.org` (the free public OSM geocoder) once per listing with a 200 ms sleep between calls. Nominatim's usage policy is 1 req/s; at 50 listings the page would need ~55 s minimum and was getting rate-limited / 429'd in practice, so most listings fell through to the Toronto-random-offset fallback or just never got a marker. The right fix is to geocode once and cache, not on every page load.

**Fix:**
1. Migration `database/migrations/add_listings_coordinates.sql` adds `latitude`, `longitude`, `geocoded_at` columns + a partial index on `(latitude, longitude)` (useful later for viewport bounding-box queries).
2. New backend endpoint `POST /api/geocode/batch` (in `backend/server.js`) takes a list of listing ids, uses **Google Maps Geocoding** (already wired with `GOOGLE_API_KEY`), and writes lat/lng back onto the row using the service role key. Cache hits skip the Google call entirely.
3. `fetchListings()` in `listings.html` selects `latitude, longitude` alongside the row.
4. `updateMap()` partitions listings into "have cached coords" and "needs geocoding." The former get markers instantly; the latter are sent to `/api/geocode/batch` in **one** request, then markers are added from the response. No more per-listing Nominatim, no inter-listing sleep.

**Required deployment steps** (one-time):
- Apply `database/migrations/add_listings_coordinates.sql` in the Supabase SQL editor.
- Set `SUPABASE_SERVICE_ROLE_KEY` env var on Railway. Without it, `/api/geocode/batch` can still geocode, but RLS will block writing coords back to rows the requesting user doesn't own, so caching effectively won't work for other people's listings.

**Follow-ups not done in this PR:**
- Viewport bounding-box query: when the map pans/zooms, refetch listings within current bounds (`.gte/.lte` on latitude/longitude) instead of always returning 50 newest. The partial index supports this already.
- Geocode-at-write: when a new listing is created, call `/api/geocode/batch` with its id before redirecting. Right now coords are populated lazily on first map view.
- The dead `geocodeLocation()` function in `listings.html` (lines ~1044-1128) is unreferenced after this change. Leaving it for one deploy cycle to be safe, then delete.

---

## 2026-05-17 — Unwanted black backgrounds across the whole site

**Symptom:** Site rendered with near-black backgrounds and dark slate panels on every page, even though no commit had explicitly turned the site dark. Hasan reported "idk where the black background thing came from."

**Root cause:** Three CSS files contained `@media (prefers-color-scheme: dark)` blocks that auto-flipped colors when the browser detected the user's OS was in dark mode (Windows 11 default). The worst offender was `frontend/modules/css/variables.css` which inverted the entire `--color-gray-*` scale — so `--color-gray-50` became `#111827` (near-black) in dark mode. Anything using `var(--color-gray-50)` as a background went near-black. `frontend/css/ios-native.css` did the same for `--ios-background`, and `frontend/map-integration.css` darkened map popup styles.

**Fix:** Deleted all three dark-mode media query blocks (91 lines total) and added `color-scheme: light;` to `:root` in variables.css. The `color-scheme` declaration tells the browser the site is light-only, which also prevents the user agent from applying its own dark-mode adjustments to scrollbars and native form controls.

**What didn't apply:** No JS was toggling dark mode dynamically (grepped `prefers-color-scheme` across `frontend/**/*.{js,html}` — zero matches), and there was no `frontend/build/` directory with stale copies, so editing the three source files was sufficient.

**If we want a proper dark mode later:** Don't put it back via `prefers-color-scheme` alone — the gray-scale inversion in variables.css is too aggressive and breaks components that assume light grays. Add a `.dark` class toggled by a user-controlled switch, and define dark-mode variables under `:root.dark`. Then the user opts in instead of inheriting the OS preference.
