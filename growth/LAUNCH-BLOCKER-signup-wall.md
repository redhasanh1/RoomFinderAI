# The sign-in wall is the biggest thing standing between the app launch and supply

Found while the app sits in Play review. Worth fixing before it matters,
because on launch day it decides whether an install becomes a listing.

## What happens now

`PostFragment.onResume()` calls `requireSignIn()`. A signed-out person who
installs the app and taps **Post** gets a modal before touching anything:

> **Sign in to post a room**
> Your listing is attached to your account, so renters can message you
> about it. It only takes a moment.

Choices are *Sign in* or *Not now*, which returns them to Home. There is no
third door.

## It was not a careless decision

The comment above the method records why:

> a user filled in bedrooms and bathrooms, added photos, read the preview -
> and only then got "Please sign in to post a listing" and got thrown to the
> login screen, with the whole form behind them. Nothing was saved.

So the alternative that was tried is worse. Gating at submit with no draft
saving means a landlord does ten minutes of work and loses all of it. Gating
on entry costs one tap instead. Given only those two options, entry is the
right call and the previous author chose correctly.

## Why it still costs us the launch

Both options are bad, and the market decides how bad. A landlord who has
never heard of RoomFinderAI, arriving from a Facebook post, meets a demand
for an account before seeing anything the app does. In particular they never
reach the one feature that is genuinely better than the website:

  photo in -> vision model writes the title and description, suggests a price

That is the entire pitch. It is behind the wall. We are asking for commitment
before showing value, from someone with no reason to trust us, who already
has Kijiji.

## The third option

**Let them build the listing signed out, then require the account at publish,
and carry the draft through the login round trip.**

  1. Post tab opens straight into the photo step. No dialog.
  2. They add photos. The AI drafts title, description and price. They see
     the thing work.
  3. They hit Publish.
  4. *Now* ask for the account - at the moment they have something to lose
     and a reason to care.
  5. Restore the draft after login and publish it.

Step 5 is the whole difference. The bug that caused the entry gate was not
"we asked at the wrong time", it was "we did not save their work".

## What it needs

`ListingDraftService` already exists and `/api/listings/draft` and
`/api/analyze-property-photo` are both live in production (verified). The
missing piece is persisting in-progress form state across the login activity
and restoring it on return - SharedPreferences or a saved-state handle
holding the fields, photo URIs and current step.

Not a one-line change, which is why it is written down rather than done in
passing. But it is contained, it is the highest-leverage change available on
the supply side, and it cannot ship until after the current review completes
anyway.

## Order of value on the supply side

1. **Remove the entry gate, keep the draft.** Every install currently has to
   spend an account before seeing anything.
2. Cut the seed listings that are not in the GTA. Someone arriving from a
   Brampton post should not see Vancouver and Montreal.
3. Write real descriptions. Seven of nine listings say "No description
   provided".

None of these need more traffic. They decide what happens to the traffic
already coming.
