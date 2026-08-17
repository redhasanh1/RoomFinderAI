# RoomFinderAI for iOS

A native SwiftUI shell around the live roomfinderai.com site.

```bash
./run.sh            # build, install and launch on the simulator
open RoomFinderAI.xcodeproj
```

Xcode is installed but `xcode-select` still points at the Command Line Tools,
so every command here sets `DEVELOPER_DIR` rather than requiring `sudo
xcode-select -s`. `run.sh` does it for you.

## Why a shell and not a rewrite

`RoomFinderAI-IOS-CLOSED/` holds an earlier native app: 276 Swift files on
disk, of which the Xcode project referenced 43, sitting beside thirty Ruby
scripts named things like `remove_all_missing_files_comprehensive.rb`. It had
drifted months behind the website and could not be brought back into line
without reimplementing every feature twice, forever.

This app renders the site the users already have, and adds the things a web
page cannot do for itself:

| Native | What it replaces |
|---|---|
| Tab bar across five sections | The site's fixed header |
| Overflow menu | The site's footer and "More" dropdown |
| Share sheet | Nothing — a web view has no address bar to copy from |
| Offline screen and banner | "Safari cannot open the page" |
| Pull to refresh, swipe back | Browser chrome |
| Sign in with Apple, Google via `ASWebAuthenticationSession` | Popup flows that cannot work in a web view |
| Push notifications, badges | — |
| Universal links and `roomfinderai://` deep links | — |
| Haptics | — |

Every page ships the moment it ships on the web. There is no second codebase
to keep in step.

## Layout

```
RoomFinderAI/
  App/       entry point, configuration, tab definitions, deep-link router
  Web/       the WKWebView store, its SwiftUI host, injected CSS/JS, Safari
  UI/        tab bar, per-tab browser screen, splash, error screen, theme
  Services/  network monitor, haptics, push, share, Google and Apple sign-in
  Resources/ Info.plist, entitlements, privacy manifest, asset catalog
```

The Xcode project uses a file-system synchronized group, so **adding a Swift
file to `RoomFinderAI/` is all it takes** — there is no membership list to
update, which is the failure mode that left the old project with 233
unreferenced files.

---

## Before this can ship

Five of these need an account only you can sign into. The app builds, runs and
works today without them; each one unlocks the feature next to it.

### 1. Apple Developer team — required

In Xcode: select the RoomFinderAI target → Signing & Capabilities → pick your
Team. Then in the Developer portal, on the `com.roomfinderai.app` App ID,
enable:

- **Sign in with Apple** — without it `AppleAuthService` fails at runtime
- **Push Notifications** — without it the device never gets a token
- **Associated Domains** — without it universal links do not open the app

The entitlements file already declares all three
(`RoomFinderAI/Resources/RoomFinderAI.entitlements`). The portal has to agree
or signing fails.

### 2. Google Cloud Console — required for Google sign-in

Google refuses OAuth from embedded web views, so the app runs the flow in
`ASWebAuthenticationSession`. That needs one redirect URI registered against
the **existing Web client** (no new client ID):

> APIs & Services → Credentials → your OAuth 2.0 Web client → Authorized
> redirect URIs → add
> `https://www.roomfinderai.com/api/auth/google/native-callback`

The backend already allowlists exactly that URI and bounces it to
`roomfinderai://auth/google?code=…`. **Until this is added, tapping "Continue
with Google" in the app returns `redirect_uri_mismatch`.** Email/password and
Sign in with Apple are unaffected.

### 3. Universal links — optional

`frontend/.well-known/apple-app-site-association` is in place but still says
`TEAMID`. Replace it with your ten-character Apple Team ID. The server
deliberately returns 404 while the placeholder is present, because iOS caches
a broken association for days.

Custom-scheme links (`roomfinderai://listings.html`) work now regardless — the
app is tested with them.

### 4. Push notifications — optional

Create an APNs key in the Developer portal and wire it to whatever sends the
mail today. `PushService` already registers, stores the token and routes
`{"url": "listings.html?id=…"}` payloads to the right tab.

Permission is asked from the More menu, never at launch: iOS grants one
system prompt per app, and asking before someone has seen a listing is how
apps get permanently denied.

### 5. App Store listing — required

Screenshots, description, support URL, and the privacy questionnaire. The
privacy manifest (`Resources/PrivacyInfo.xcprivacy`) already declares email
address and user content, collected for app functionality, not used for
tracking.

---

## Known review risk

Guideline 4.2 rejects apps that are only a web page in a frame. This one has
native navigation, offline handling, share, push, deep links and two native
sign-in flows — but the content is genuinely the website, and that is a
judgement call the reviewer makes, not a box that gets ticked.

If it is rejected on 4.2, the strongest single answer is a native search
screen for listings — the API already exists — so browsing does not touch the
web view at all. Worth building only if asked for.

Guideline 4.8 is handled: the app offers Sign in with Apple alongside Google.

## Testing

`run.sh` refuses to install when the build fails, so what you test is always
what you just compiled.

Deep links drive the app from the command line without tapping:

```bash
xcrun simctl openurl booted "roomfinderai://listings.html"
xcrun simctl openurl booted "roomfinderai://ai-negotiator.html"
xcrun simctl io booted screenshot out.png
```
