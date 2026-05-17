# LEARN.md — RoomFinderAI design log

Running notes on bugs we hit, what worked, what didn't, and what to remember next time. Newest entries on top.

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
