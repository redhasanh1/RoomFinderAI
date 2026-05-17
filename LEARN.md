# LEARN.md — RoomFinderAI design log

Running notes on bugs we hit, what worked, what didn't, and what to remember next time. Newest entries on top.

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
