# What actually makes a landlord install and use the app

Research, 2026-09-02. This one changes the plan for launch day.

## The reframe that matters most

**Posting a room is not an app-worthy behaviour. Managing inquiries is.**

A landlord with one or two rooms posts maybe one to four times a year. Nothing
retains an app at that frequency — average **Android day-30 retention is 3.8%**.
An app whose job is "post a room" gets installed once, used once, and is dead
inside a month.

The inquiry stream is different: daily for the two or three weeks a room sits
empty, and in a 5.4%-vacancy market it is a race. That is the only landlord
behaviour with app-native frequency.

So: **web-first for posting, app-first for the inbox.**

Corollary worth sitting with: the *renter* side is where app-first is actually
evidenced — 73% of renters already search by app, up from 64% a year ago, and
they search repeatedly over weeks. Landlord installs will always be a small,
low-retention cohort. Do not judge the app by that number.

## The signup wall — the best-evidenced item in any research this session

This confirms `growth/LAUNCH-BLOCKER-signup-wall.md` with harder numbers.

- **The $300 Million Button.** A large retailer replaced "Register" with
  "Continue" and moved registration to after the transaction:
  **+45% completed purchases, +$300M in the first year**, $15M in month one.
  They also found 45% of repeat customers had multiple accounts and 160,000
  password resets a day, **75% of which never ended in a purchase.**
- **Baymard:** 18% of abandoners cite "the site wanted me to create an
  account". Other roundups put forced-account abandonment nearer 26%.
- **~25% abandon when required to set a password.** Each extra authentication
  step costs 10-15%. Mobile signup converts 5-15 points worse than desktop.

Reported signup conversion by method: email+password 35-55%, Google OAuth
55-75%, **magic link / OTP 70-85%**. (Softer source; the direction is
consistent with everything above.)

**Phone-number OTP as primary auth, no password, is the highest-leverage
single change available.** It removes the password abandonment *and* it hands
us the SMS channel, which the rest of this plan depends on.

## Do not force the app install

**Google's own test:** an app-install interstitial caused **69% of visitors to
abandon the page entirely**, against a 9% tap rate on "Get App". Google removed
it, replaced it with a slim banner, and saw **+17% one-day active users on the
mobile site.** They then made interstitials a mobile search ranking penalty.

And we have negative leverage: vacancy at a five-year high, Brampton and
Mississauga rents down 7%+, student arrivals down ~60%. Landlords are the
courted side right now. Any friction we add, they answer by posting on
Marketplace instead, where it is free and account-light.

## Push notifications are not the hook — the reply is

Push alone does not justify an install. **SMS gets 90-98% open rates with 90%
read inside three minutes**, against 20-30% for email. "Someone asked about
your room" can be delivered by text with no install at all, and read faster
than a push.

What survives that test is not the alert, it is the reply:

> Notification arrives → an AI-drafted reply is already written → the landlord
> taps Send from the lock screen, or edits it in two taps.

Android's direct-reply-from-notification is structurally impossible on the
web. **Alert is SMS's job. Zero-friction reply is the app's job.**

This also plugs straight into the strongest hook from research 01 — AI
answering and pre-qualifying inquiries.

**Android 13+ caveat:** request the notification permission at the moment of
value, right after their first inquiry lands. Never on first launch. Asking on
the splash screen is how opt-in falls below 50%.

## Install incentives: no credible evidence they work on supply

This was the weakest evidence area, and the finding is a negative one worth
respecting. There is **no published, numeric case study of an install
incentive working on the supply side of a marketplace.** What exists is vendor
content marketing with no figures.

What is observable, across OfferUp (>90% of transactions in-app), Vinted,
Poshmark and Airbnb, is the same pattern every time: **none of them paid for
supply-side installs.** They made the app the only comfortable way to do a job
the supplier already wanted done. Copy that, not the coupon.

Cash install bonuses specifically: US Android CPI averages **~$3.60**, and
incentivised installs are the classic fraud vector and retain far worse than
organic. A money furnace at this stage.

## The one mechanism with a track record

**Airbnb's response rate.** It is the percentage of new inquiries answered
within 24 hours over the trailing 30 days, it is a **search ranking factor**,
and Superhost requires **90% within 24 hours**. Airbnb never begged hosts to
install the app — it made response speed a scored, visible, ranked asset, and
the app became the only practical way to hit the bar.

A visible Response Score that affects listing rank is the only mechanism found
that pulls suppliers onto an app without paying them. Flagged honestly: this
is reasoning by analogy, not measured evidence for rentals.

Supporting numbers: contacting a lead within 5 minutes rather than 30 makes
you **~100x more likely to reach** them and **~21x more likely to qualify**
them (15,000 leads, 100,000 contact attempts). The average renter contacts
**more than four** landlords and **71% expect a reply within 24 hours.**

## Age is not the blocker — frequency is

**~70% of Canadians aged 55+ use mobile apps daily.** Small individual
investors hold roughly half of all rental property value in Ontario. A
55-year-old with two rooms will happily install WhatsApp, because she uses it
hourly. She will not retain an app she needs four times a year.

## Play Store cold start, honestly

**A new app with no reviews and no ranking gets essentially no organic Play
traffic, and no ASO trick fixes that.** Ranking is driven by install volume and
velocity, retention and ratings. We have none of them. You cannot optimise out
of a cold start, only import traffic from somewhere you already have it.

What is real and free:

- Play indexes the **full 4,000-character long description** (unlike Apple).
  **Long-tail geo is the only winnable ranking**: "rooms for rent Mississauga",
  "room rental Brampton", "shared accommodation Scarborough". Nobody competes
  for those. "Rentals" is unwinnable.
- **In-App Review API** — trigger the rating prompt after a positive event, a
  booked viewing, never on launch. The first ~20 ratings matter
  disproportionately when the listing currently shows none.
- Store Listing Experiments and custom store listings — set up, but no signal
  at low volume.

Realistic install sources, ranked:

1. **Our own website traffic**, via a slim banner and proper deep links. This
   will be roughly 80% of installs for the first six months. Everything else
   is rounding error.
2. **Transactional SMS at the first inquiry**, deep-linked into that
   conversation. The highest-intent install trigger available.
3. Manual community distribution — the Facebook groups already mapped.
4. The renter side, if install velocity is the goal.

## Build order

1. **Kill the signup wall.** Post first, register at publish, phone OTP only,
   three mandatory fields instead of eight. Best evidence-to-effort ratio in
   this document.
2. **SMS the first inquiry — do not require the app for it.** Landlords who
   never install still get value, and we hold the channel either way.
3. **Make the app the reply surface.** Push carrying an AI-drafted response
   plus Android direct-reply. "Answer a renter in ten seconds from your lock
   screen." That is the app-only proposition.
4. **Ship a visible Response Score that affects listing rank.**
5. Geo long-tail the Play listing, wire the review prompt to a positive event,
   put a slim banner (never an interstitial) on the site.

## Evidence quality, stated plainly

| Claim | Strength |
|---|---|
| Signup walls cost 18-45% of supply-side conversion | **Strong** |
| Fast response drives lead conversion | **Strong** |
| App-install interstitials destroy conversion | **Strong** — Google's own test |
| Apps out-engage mobile web ~3x | Moderate — 2018, e-commerce not rentals |
| Push lifts retention 2-3x | Moderate — vendor data, selection bias |
| Landlords will install for lead alerts | **Speculation** — no survey ranks this as a landlord pain |
| Install incentives work on marketplace supply | **No credible evidence found** |
| % of rental listings created on mobile | **No published data exists.** Do not cite a number |

## One thing to verify

Personal developer accounts created after **13 Nov 2023** must run a closed
test with **12 testers for 14 continuous days** before production access. The
app is in production review now and Play let the release through, so this
presumably does not apply to this account — but it silently blocks launches
and is worth confirming rather than assuming.
