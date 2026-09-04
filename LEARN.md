# LEARN

Running log of non-obvious fixes and the reasoning behind them. Newest on top.

## 2026-09-04 — The sign-in wall, and the bug that only a running emulator found

`PostFragment.onResume()` called `requireSignIn()`, so a signed-out person who
installed the app and tapped **Post** got a modal before touching a single
field. That gate was not careless — the comment above it records that gating at
*submit* had already been tried and was worse: someone filled the whole form,
tapped Publish, was thrown to the login screen, and lost everything. Given only
those two options, gating on entry was the right call.

The third option is what actually removes the choice: **build the listing
signed out, ask for the account at Publish, and carry the draft across the
login round trip.** The bug that forced the entry gate was never "we asked at
the wrong time", it was "we did not save their work". So `saveDraft()` runs
before `LoginActivity` starts, `restoreDraft()` runs in `onResume()`, and
`onPause()` saves too — Android kills backgrounded processes without warning,
and a landlord who switches away to look up a postcode must not come back to an
empty form. Draft lives in SharedPreferences and is cleared only after the
server accepts the listing, never on a failed publish.

The piece that made this small: **photos needed no special handling.**
`uploadedPhotoUrls` already holds remote URLs, because `AttachmentUploadService`
uploads each photo the moment it is picked. There are no `content://` URIs to
keep alive across a process death and no permission to re-request — persisting
the URL strings is the whole job.

**The bug worth recording.** The first version compiled clean and looked right.
Run on an emulator, it greeted a returning landlord with a toast: *"Pick a type
of place to continue"* — about a chip that was re-selected two lines later.
Cause: `setText()` on a restored field fires its `TextWatcher`, which calls
`validateStep1()`, which ran while `selectedPropertyType` was still empty
because the text was being restored before the model. Fixed with a
`restoringDraft` guard (cleared in a `finally`, so a throw mid-restore cannot
leave validation permanently off) plus reordering so model and chips are set
before any text. A compile would never have caught this, and it would have
shipped as the first thing a returning landlord saw.

Also learned the hard way about restoring chips: the property type is stored
normalised (`house`) while the chip reads `🏢 House`, so it matches on
`contains`, while bedrooms/bathrooms store the chip's own text and match
exactly. Get it wrong and it is silent — the value posts correctly and the
screen just looks unanswered.

Verified on an API 35 emulator, signed out, end to end: Post opens straight to
the form with no dialog and "Let AI write it" visible; filled four fields and
three chips; backgrounding wrote every field to
`shared_prefs/post_listing_draft.xml`; `am force-stop` then relaunch restored
step, both chips, all text, no toast; added a photo, reached Review, tapped
Post Listing and got "Almost there" with the draft saved at step 4 including
the uploaded photo URL.

One pre-existing rough edge noticed and left alone: after granting the photo
permission the picker does not reopen, so you have to tap "Tap to add photos"
a second time. Not caused by this change, but it is friction on the exact step
the whole pitch depends on.

## 2026-09-04 — Why every shared listing link opened Chrome instead of the app

Play flagged "one deep link may be failing because the domains are not
associated with the app" on the 1.0.2 release. The cause was a missing file, and
the reason it was missing is more interesting than the fix.

The manifest has declared an App Links intent-filter for
`https://www.roomfinderai.com/listing_details.html` with `android:autoVerify="true"`
since before launch. That flag makes Android fetch
`https://www.roomfinderai.com/.well-known/assetlinks.json` at install time and
check that the domain names this package and this signing certificate. The file
returned **404** — confirmed live, `Cannot GET /.well-known/assetlinks.json` —
so verification failed silently and the intent-filter never took effect. Every
listing URL anyone pasted into a group chat opened a browser, and the app then
had to sell itself a second time to someone who had already installed it.

Two details cost time and are worth writing down. **First, the file cannot just
be dropped in `frontend/`.** `express.static` defaults to `dotfiles: 'ignore'`,
so any path segment starting with a dot is skipped — a file at
`frontend/.well-known/assetlinks.json` would 404 exactly as the missing one did,
and it would look correct in the repo while being invisible on the wire. It is
served as an explicit `app.get` registered *before* the static middleware
instead. **Second, the fingerprint is Play's app-signing certificate, not the
upload certificate.** Play re-signs every build with its own key, so the upload
fingerprint would never match what is actually installed on a device;
`1E:49:...:FE:71` comes from Test and release → App integrity → App signing.
Also: Android does not follow redirects when verifying, which is why the apex
domain's 301 to www does not cover it — `roomfinderai.com` would need its own
intent-filter and its own copy of the file.

Verified by booting the server on :3999 and requesting the path: 200,
`application/json`, correct package and fingerprint. It does nothing until the
backend deploys, and Android only re-verifies on install or update — devices
that already have 1.0.2 will not pick it up until the next release.

## 2026-08-26 — People and Messages: what to cut, and what to leave alone

Finishing the tab sweep. Both screens are in better shape than Profile was;
neither had a fake action. What they had was chrome.

**Messages.** Two things removed:

  - A green dot labelled **"Active now"** in the header. Active now referred to
    nothing - not presence, not unread state, not connectivity. It rendered
    unconditionally. A status light that never changes is worse than no status
    light, because people read it as information and it is not.
  - A **"Quick tips"** footer whose one tip was "AI Assistant can help you
    negotiate better deals" - which is what the AI Assistant card immediately
    above it already says, in larger type, next to the control that does it.

**People was left alone, and that is the more interesting call.** Every card
carries a "Looking for a sublease" pill while the tab above says Subleases and
the count says "5 subleases", which looks exactly like the redundant per-row
badge worth deleting. It is not: the pill comes from `SubleaseRequest.isOffering()`
and reads "Offering a sublease" for the other direction. Today's data happens to
be all one kind, so the badge looks like it repeats the filter. Deleting it
would have removed the only thing on the card telling you which way round the
post is - which matters more than the tidiness.

The general rule this pass: cut what restates something adjacent or refers to
nothing, keep what carries information the data merely happens not to vary today.

## 2026-08-26 — Two more from the same sweep: a lost form, and a dormant verification bypass

Continuing the audit past the Profile screen.

**Posting while signed out threw the whole form away.** The only auth check in
PostFragment lived in `submitListing()`, which runs on the final tap of step 4.
A signed-out user picked a property type, wrote a title, typed an address, set a
rent, chose bedrooms and bathrooms, added photos, read the preview - and got
"Please sign in to post a listing" and a trip to the login screen, with none of
it saved. The gate now runs on entry, so it costs one tap instead of a form.
"Not now" returns to Home rather than leaving someone parked on a screen they
cannot finish, which would just re-prompt on the next resume.

**A verification bypass that is dormant rather than absent.**
VerificationActivity can display the six digit code on screen and, for three
hardcoded addresses, show a "Skip Verification (Demo Mode)" button whose handler
calls `setEmailVerified(true)` and stores the user locally - no server involved.

It does not fire in production, and the reason is worth stating precisely: the
block is guarded by `demoVerificationCode != null`, and that is only populated
by scraping a code out of the server's response message. The live API does not
put one there - `/api/register` answers
`{"message":"Verification code sent to your email"}` and nothing else, which I
confirmed by calling it. So today it is unreachable.

That is a thin thing to be safe by. If any backend ever includes a code in a
message, this screen would print a stranger's verification code to whoever typed
their address, and the debug line underneath prints the code and the email as
well. It is now compiled out of release with `BuildConfig.DEBUG` and left
working for local development, which keeps the convenience without shipping it.

Also checked and deliberately left alone: the remaining "coming soon" toasts
live in ToolsFragment and MortgageCalculatorFragment, reachable only through
`toolsCard` in the profile layout, which is `android:visibility="gone"`. They
are dead code, not user-facing promises.

## 2026-08-26 — The Profile screen was almost entirely fictional

Prompted by getting caught claiming the app was "tested" and then finding a
Delete account button that deleted nothing, I went looking for the rest of that
class of bug rather than clicking around. `grep -rniE "coming soon|TODO"` over
the source found it in about a minute. On one screen:

  - **The stats were hardcoded.** `animateCounter(binding.savedCount, 0, 12, ...)`,
    `postedCount 3`, `messagesCount 5`. Every account on every device was shown
    "12 saved, 3 posted, 5 messages", animated so it looked live. Invented data
    presented as the user's own is worse than an obvious placeholder, because
    nobody thinks to doubt it.
  - **Three of four rows were dead.** "Manage my listings", "Settings" and
    "Help & Support" each raised a "- Coming Soon" toast.
  - **Favourites could never work.** Both heart buttons did
    `listing.setFavorite(!isFavorite)` and left `// TODO: Save to local storage`
    where the write belonged, while FavoritesFragment read a SharedPreferences
    key `favorite_listings` that no code anywhere wrote. The loop could not
    close even in principle: tap heart, see "Added to favorites", open Saved
    rooms, find it empty. Forever.

The common shape is worth naming: **the UI was built and the call was never
wired**, then a toast was added so the button felt like it did something. The
account-delete bug was the same shape. In every case the backend already had
the endpoint - /api/favorites, DELETE /api/listings/:id and /api/account/delete
have all existed the whole time.

What changed:

  - New `FavoritesService` against /api/favorites (add, remove, list). The heart
    now reflects what the server stored rather than the tap, favourites live on
    the account so the website shows the same list, and saving is gated at the
    action for signed-out users instead of at the tab.
  - Saved rooms loads from the server. Its errors say what went wrong instead of
    rendering as "you have saved nothing".
  - New `MyListingsFragment`: your posted rooms, with delete. A marketplace
    where you cannot take your own listing down means listings outlive the room.
  - Stats come from real counts, and the messages counter is gone rather than
    guessed at.
  - Help opens /support.html, falling back to a mailto.
  - **Settings was deleted, not built.** There is nothing behind it - no
    notifications, no theme, no language - and a row whose only function is to
    apologise for itself is worse than no row.

Two layout bugs fell out of testing the above, both invisible in XML:

  - On the listing detail screen the toolbar had no status bar inset, so back,
    favourite and share sat at y=42..168 while the status bar owned everything
    above ~110. Two thirds of every one of those buttons ate the touch. This is
    why my first three attempts to favourite a room did nothing at all and I
    briefly suspected my own networking code - the tap never reached the app.
    targetSdk 35 is edge to edge whether you ask or not.
  - In fragment_favorites.xml the title had *no constraints*, so it fell to 0,0
    in a ConstraintLayout, and the RecyclerView was pinned to the parent top as
    well. The first saved room drew on top of the words "Saved rooms".

Verified end to end on device against a throwaway account whose inbox I could
read: register, verify, sign in, favourite a room, confirm via
`GET /api/favorites` that the server really had it, reopen the app cold, see it
in Saved rooms and "1 saved" on the profile. Then deleted the account.

## 2026-08-26 — "Delete account" deleted nothing, and production has drifted from git

Profile > Delete account ran exactly this and nothing else:

    authManager.completeLogout();
    authManager.clearAllAuthData();
    prefs.edit().clear().apply();
    Toast "Account deleted successfully"

Every call is local. The profile row, listings, sublease posts, favourites and
AI conversations stayed on the server and the address stayed taken, while the
confirmation dialog promised "All your data, listings, and chat history will be
permanently deleted." It also made two things submitted to Google that day
false: the Data safety questionnaire declares deletion works, and the public
/delete-account.html page Play requires documents the in-app steps.

I diagnosed it backwards at first and it is worth recording why. Assuming a
fake button meant no server-side capability, I wrote POST /api/account/delete,
committed it and pushed. Then I tested against production and got:

    {"success":true,"message":"Your account and all associated data
      have been deleted."}

That is not the response my endpoint returns. Probing further: bogus routes
under /api/ answer 404, so the path genuinely existed; the very first request,
sent seconds after the push and long before a restart could finish, already
answered 401 rather than 404; and `git log --all -S "associated data have been
deleted" -- backend/server.js` finds nothing on any branch. main had no such
route before my commit.

So the deployed backend contains code that is in no branch of this repository.
The server could always delete accounts, correctly, including refusing a wrong
password without touching the account - verified end to end with a throwaway
address whose inbox I could read, registering, verifying the emailed code,
logging in, failing a delete with the wrong password, confirming the account
survived, then deleting for real and confirming login stopped working. The only
bug was that the Android app never called it.

I removed my endpoint again. Leaving it in would have been worse than
redundant: Express dispatches to the first matching route, so one silently
shadows the other by definition order, and mine deleted rows from a table list
I inferred by grepping `.from('...')` calls while the deployed one was written
against the real schema. Shadowing a correct implementation with an inferred
one, for an operation nobody can undo, is not a trade worth making.

Two lessons. Test the assumption before building on it - one curl against
production would have saved the whole detour. And main is not a trustworthy
picture of what is serving requests on this project; that drift is worth
chasing separately, because the next person to reason from the repo about
production behaviour will be wrong in some other way.

The app side is fixed and verified on device: the dialog asks for the password,
the request goes to the endpoint that was already there, and local state is
cleared only inside the success callback. On a wrong password the app stays
signed in and shows "Incorrect password", which is exactly what the old code
could not do, because it never waited to find out.

## 2026-08-26 — Android app: a tablet-only crash, an overlaid chat, a stretched badge

Google Play requires 7-inch and 10-inch tablet screenshots before an app can be
submitted, so the app had to be driven at tablet geometry for the first time
(`adb shell wm size 1600x2560; wm density 320`, rather than building a new AVD).
It died on launch, every time:

    IndexOutOfBoundsException: Inconsistency detected. Invalid view holder
    adapter position CarouselHolder{... position=18 ... oldPos=5 ...}
    RecyclerView{... app:id/recyclerView}, adapter: HomeFeedAdapter

The first guess was wrong and worth recording: that message usually means the
adapter was mutated during a layout pass, so `submit()` was made to defer via
`recyclerView.isComputingLayout()`. It changed nothing, which ruled the theory
out rather than confirming it.

The real cause was in `HomeFragment.onMoreLoaded`. The progressive loader lands
a second batch of rooms, and the code did:

    applyFiltersProgressive();                        // rebuilds `listings`
    adapter.notifyItemRangeInserted(previousFilteredSize, newFilteredItems);

counted in **listings**. `HomeFeedAdapter` is not indexed by listing - a row is
a header, a shelf, a card or the summary - so arriving rooms can add an entire
shelf, move the "All rooms" header and push the summary down. Announcing "N
items appeared at listing index K" was a lie about the structure; RecyclerView's
bookkeeping stopped matching `getItemCount()` and the next layout threw. A phone
viewport attaches few enough rows to get away with it. A tablet does not, which
is why it reproduced 100% at 1600x2560 and had been hiding on phones. The fix is
`adapter.submit()` - only the adapter knows how listings map to rows. The cost
is the insert animation on a batch that lands within a second of the first.

Two more defects surfaced from looking at the same screens at tablet width:

**The AI negotiator drew its welcome panel on top of a restored conversation.**
`updatePrimerVisibility()` was called when setting up and after sending, but not
on the history-restore path, so reopening the chat rendered the icon, the blurb
and all three suggestion chips over the messages, legible through each other.
Sending hid it, so the bug only ever appeared on the way back in - which is how
it survived this long. It is now called from all three places that change the
message list.

**The "Looking for a sublease" badge was `layout_width="0dp"` with
`layout_weight="1"`,** so the pill stretched the whole row and drew as a long
empty bar with three words at the left end. A pill has to hug its text; a
`Space` with the weight does the pushing instead. On a phone the card is narrow
enough that it read as a slightly wide badge.

Unrelated but found on the way: `AIChatFragment.java` declared `class
AiChatFragment`. Windows is case-insensitive so it had always resolved, but
javac compares exactly and failed the moment that file was actually recompiled.
Renamed the file to match the class.

The general lesson: a screen-size the app has never been run at is a cheap
fuzzer. Three real bugs, one of them fatal, fell out of resizing the emulator
for a screenshot.

## 2026-08-24 — Android app: empty listings, duplicate loads, unreadable cards

The Android app built and launched fine but showed "No Properties Found" on every
screen. The cause was in the transport, not the UI: `SupabaseClient` sends
`apikey`/`Authorization` headers built from `ApiKeys.SUPABASE_ANON_KEY`, which
falls back to an empty string when `local.properties` has no keys. PostgREST
answers an unauthenticated request with `401 {"message":"No API key found in
request"}`, the service swallows it into an empty list, and the user sees an
empty marketplace. Worth noting the model was never shaped for Supabase in the
first place: `Listing`'s `@SerializedName` values (`location`, `address`,
`propertyType`, `imageUrl`, `createdAt`) match the public roomfinderai.com API,
not the raw table columns (`city`, `house_type`, `created_at`), so even a valid
anon key would have parsed half the fields as null. The PostgREST filter URLs are
also malformed — `price.gte.1000` instead of `price=gte.1000`.

The fix inverts the priority. A new `WebApiListingsSource` talks to
`https://www.roomfinderai.com/api/listings`, which needs no credentials and
returns exactly the JSON shape the model expects. `SupabaseClient` now tries
Supabase only when `ApiKeys.hasSupabaseKey()` is true, and falls through to the
web API whenever the key is absent or a query comes back empty. Filters and
search have local equivalents so the fallback keeps its semantics rather than
silently returning everything. Result: 15 live listings render with no secrets
in the APK.

Two more bugs surfaced from the same launch. `MainActivity.onCreate()` called
`loadFragment(new HomeFragment())` *and* `setSelectedItemId(navigation_home)`
with the navigation listener already attached, so every cold start built two
HomeFragments and ran the listing load twice; the initial tab is now loaded
before the listener is attached, and re-tapping the current tab no longer
rebuilds the fragment. And `ListingDetailActivity.getImageUrls()` read only
`listing.getMedia()`, which the web API never populates — galleries showed a
placeholder. `Listing` now carries the API's `imageUrls` array and exposes
`getAllImageUrls()` (cover, then gallery, then legacy media, de-duplicated).

On the UI: the listing card put the title and an 18sp bold price in one
horizontal row, so titles were cut to about seven characters ("3-Bedr…",
"Spacio…"), the property type was printed twice, and the un-favourited heart was
drawn in `heart_red_dim` — red, which read as "everything is saved". The card was
rebuilt with a two-line title block of its own, the price on its own line, the
type as a single badge over the photo, and a neutral outline heart. On the home
screen the empty/error states were `wrap_content` children of a CoordinatorLayout
centred over the whole page, so "No Properties Found" printed on top of the
Explore Tools cards; they are opaque full-bleed panels now.

Sign-in: the Apple button existed in `activity_login.xml` with no click listener
at all, and Google used the native `GoogleSignIn` flow with
`requestIdToken(BuildConfig.GOOGLE_OAUTH_CLIENT_ID)` — an empty string when
unconfigured, which throws. Both now route through `SupabaseOAuthManager`, a
Custom Tab against `/auth/v1/authorize?provider=…` with a
`roomfinderai://auth-callback` deep link: the same flow the website's
`signInWithOAuth({ provider })` uses. Google is enabled on the project and 302s
to `accounts.google.com`; Apple answers 400 because the provider is not enabled,
so its button is hidden (`visibility="gone"`) with the handler left wired.

Emulator setup for the record: Android Studio ships no `cmdline-tools`, so
`sdkmanager`/`avdmanager` had to be installed separately, and both `.bat`
wrappers split package names on `;` under Git Bash — use `--package_file` with
one package per line. AVD `RoomFinder_API35` (Pixel 7, API 35 google_apis
x86_64, WHPX) is the reference device.
