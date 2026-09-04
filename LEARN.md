# LEARN

Running log of non-obvious fixes and the reasoning behind them. Newest on top.

## 2026-09-04 - Production is ahead of `main`, not just different from `hasan`

Worth stating separately because it changes what a deploy means.

`POST /api/account/delete` answers on production - 401 `{"error":"Email is
required"}` on an empty body, and a route that does not exist returns a plain
404 HTML page, so that is a real handler. `origin/main` has no such route. Its
implementation also differs from the one written on `hasan`, which answers
"Email and password are required" for the same request.

So production is running code that exists in **no branch**. Deploying `main`
unchanged would have removed account deletion - which Google Play's Data safety
declaration and /delete-account.html both promise works. Ported the `hasan`
version onto the deploy branch so the feature survives; the app sends
`{ email, password }`, which is what that handler expects.

The frontend, by contrast, turned out to be clean. Production's index.html
differs from main's by exactly three asset tags, and main's own
`html-inject.js` injects those three at serve time. listings.html and
listing_details.html are byte-identical to main. An earlier note in this session
claimed the frontend had drifted from every branch - that was wrong, and it was
wrong because the working tree had `hasan`'s html-inject.js checked out, which
injects different assets. **Compare against the branch you mean, not the one you
happen to have checked out.**

## 2026-09-04 — `hasan` is not `main` plus work. It is an older, smaller server.

Worth knowing before anyone deploys anything.

`backend/server.js` on the `hasan` branch is **2,276 lines smaller** than on
`main` (10,497 vs 12,773) and is missing **19 routes that production is
serving right now**:

```
/api/listings/photos            /api/listings/draft
/api/negotiate/reply            /api/negotiate/judge
/api/negotiate/reset            /api/create-checkout-session
/api/stripe-webhook             /api/stripe/customer-portal
/api/roommate-profiles (GET+POST)
/api/push-subscription (POST+DELETE)
/api/property-visits            /api/sublease/interests
/api/verify/status-batch        /api/admin/verification-document
/api/analytics/notification-dismissed
/.well-known/apple-app-site-association
/listing_details.html
```

That includes `/api/listings/draft` — the AI listing writer, which is the whole
pitch — and the three `/api/negotiate/*` routes behind the homepage's AI
negotiator. **Deploying `hasan` would delete all of it.**

Found by accident. While auditing which endpoints the Android app calls,
`POST /api/listings/photos` had no route in `server.js`, so it looked like a
second broken integration. Probing production returned
`{"success":false,"message":"No photos received"}` — a real handler. The string
"No photos received" appears nowhere in the repository on `hasan`. It is on
`main`.

The lesson: **when a route is missing from the branch you are reading, check
the other branches and production before concluding it does not exist.** The
absence was in the branch, not in the system.

Work that has to reach production must be branched from `origin/main`, not
from `hasan`. `hasan` is fine for the growth/ tracker and the Android source;
it is not a deployable server.

## 2026-09-04 — The app on Google Play could not post a listing. At all.

`PostFragment.submitListing()` sends `postalCode: ""` — the app asks the host
for one "Address" line and has no postal code field. `validateListingInput()`
did `if (!data.postalCode) errors.push('Postal Code is required')`, and an
empty string is falsy. That validation runs *before* the auth check, so it
fired for everyone.

Confirmed against production before touching anything — identical bodies, only
the postal code differing:

```
postalCode ""     -> 400 {"errors":["Postal Code is required"]}
postalCode "L4T"  -> 401 {"error":"User authentication required"}
```

The 401 is the tell: with a postal code the request clears validation and
reaches the auth gate. Without one it never does. So a landlord installed the
app, signed in, filled four steps, uploaded photos, tapped "Post Listing" — and
got a failure toast. The single action the app exists for had never worked.

Fixed on the server rather than in the app deliberately: an app-side fix ships
in the next Play release and does nothing for the copies of 1.0.2 already
installed, whereas relaxing the server repairs those the moment it deploys. The
website is unaffected — its form has a `required` postal code input, so it keeps
sending one.

Two things made this invisible. The sign-in wall on the Post tab meant almost
nobody reached step 4, so nobody hit the 400 to complain about. And neither the
Android code nor the server code is wrong on its own — the contract between
them was simply never exercised end to end before shipping.

Knock-on fixed in the same change: the app sends its one address line as *both*
`street` and `city`, and four render sites joined `street, city, postalCode`
unconditionally, so the first app listing would have displayed as
`7280 Airport Rd, 7280 Airport Rd,`. `formatListingLocation()` drops empty parts
and case-insensitive duplicates.

## 2026-09-04 — Why every shared listing link opened Chrome

Play flagged "one deep link may be failing because the domains are not
associated with the app". The manifest has declared an App Links intent-filter
for `https://www.roomfinderai.com/listing_details.html` with
`android:autoVerify="true"` since before launch, which makes Android fetch
`/.well-known/assetlinks.json` at install time. That returned **404** in
production, so verification failed silently and every listing URL pasted into a
group chat opened a browser — including for people who had already installed
the app.

Two details cost time. The file cannot simply be dropped in `frontend/`:
`express.static` defaults to `dotfiles: 'ignore'`, so anything under
`.well-known` is skipped and the file would 404 while looking correct in the
repo. (`main` already knew this — the iOS `apple-app-site-association` is served
by an explicit route directly above, for the same reason.) And the fingerprint
is Play's **app signing** certificate, not the upload certificate: Play re-signs
every build with its own key, so the upload fingerprint would never match what
is installed on a device.

Android does not follow redirects when verifying, so the apex domain's 301 to
www is not covered. `roomfinderai.com` would need its own intent-filter and its
own copy of the file — deliberately not done here, because that needs a new app
release and this fix does not.

Android only re-verifies on install or update, so devices already carrying
1.0.2 will not pick this up until the next release.
