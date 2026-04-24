# RoomFinderAI

A rental marketplace that replies to inquiries in under 60 seconds, shows you the real monthly cost of a place instead of just the rent, and helps you negotiate with landlords using patterns learned from 1,247 past conversations.

Full-stack: Node/Express + Supabase Postgres backend, vanilla-JS web client, native iOS (SwiftUI) and Android (Java) apps — all sharing the same API, deployed on Railway.

[![Node.js](https://img.shields.io/badge/Node-18-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![Express](https://img.shields.io/badge/Express-5-000000?logo=express&logoColor=white)](https://expressjs.com/)
[![Supabase](https://img.shields.io/badge/Supabase-Postgres-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com/)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT-412991?logo=openai&logoColor=white)](https://openai.com/)
[![Cloudflare Workers AI](https://img.shields.io/badge/Workers%20AI-Llama%203.2%20Vision-F38020?logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/workers-ai/)
[![Stripe](https://img.shields.io/badge/Stripe-payments-635BFF?logo=stripe&logoColor=white)](https://stripe.com/)
[![Railway](https://img.shields.io/badge/Railway-deployed-0B0D0E?logo=railway&logoColor=white)](https://railway.app/)
[![MIT](https://img.shields.io/badge/license-MIT-blue.svg)](#license)

---

## The numbers

| | |
|---|---|
| Negotiations logged and analyzed | **1,247** |
| Response templates scored with live performance data | **22** (top: 82% win rate over 45 samples) |
| External data feeds fused per listing | **15+** |
| REST endpoints | **60+** |
| SQL migrations | **27** |
| Front-end modules | **86** |
| Native clients sharing the API | **iOS + Android** |
| Auto-response p50 vs. the Zillow baseline | **< 60s vs. 12–48h** |

---

## What's interesting in here

### The negotiation engine actually learns

Every negotiation gets logged — message length, response timing, pricing strategy, landlord tone, final outcome — and fed into a learning loop.

Patterns that fell out of the dataset:

- Replies under 30 minutes win **78%** of the time. After four hours it drops to **41%**.
- 20–80 character messages close **72%** of deals. Long ones (150+ chars) close **45%**.
- Offers at 95–105% of ask win **85%**. Aggressive lowballs (70–85%) win **23%**.
- 9–11 AM on weekdays beats every other time slot.

The template picker keeps experimenting — 80% of the time it picks what's been working, 20% of the time it tries something else — with context multipliers for landlord personality (cooperative / professional / aggressive / casual) and market conditions. Cold-start bias gets diluted instead of baked in.

Code: [`ai-learning/`](./ai-learning/) — the loop, the pattern extractor, the template picker, and the persisted dataset.

### The real monthly cost of a place, not just the rent

Rent is the sticker price. The actual number is rent + utilities + commute + insurance + parking + pet fees + whatever else the listing hides. The platform computes all of it:

- **Commute** — Google Distance Matrix, driving at the 2026 IRS rate of $0.67/mile, transit tiered by distance, biking at $20/month for maintenance.
- **Utilities** — parametric by property type and bedroom count (apartments $80/br, houses $120/br, condos $90/br, studios $60).
- **Insurance** — tiered by rent band.
- **The total** — exposed as a `listings_with_total_cost` SQL view, so sorting and filtering happen at the database layer, not in JavaScript.

Why it matters: two listings at $1,800/month can easily differ by $400/month in true cost once you include a 45-minute commute and electric heat.

Code: [`backend/server.js`](./backend/server.js) + [`database/migrations/001_add_true_cost_fields.sql`](./database/migrations/001_add_true_cost_fields.sql). Deep-dive: [`FEATURE_SUMMARY.md`](./FEATURE_SUMMARY.md).

### Photos as a pricing signal

Listing photos get analyzed by Llama 3.2 11B Vision running on Cloudflare Workers AI. The worker extracts money features (granite, stainless, hardwood, exposed brick, …), spots staging issues, grades the unit A+ to C-, and produces a suggested rent from `base × location-multiplier + feature premium − flaw penalty`. It runs on Cloudflare's edge GPU, so image analysis stays off the main API's critical path.

Code: [`cloudflare-worker/src/index.ts`](./cloudflare-worker/).

### Fifteen external feeds, one surface

A listing isn't just a row in Postgres — it's joined at read-time with a pile of external context:

| Source | What it adds |
|---|---|
| RentCast | Rent estimates, sales comps, market stats |
| Walk Score + Google Distance Matrix | Walkability, commute time + cost |
| GreatSchools | School ratings by address |
| FBI Crime | Neighborhood crime stats |
| FEMA + NOAA + EPA + USGS | Flood zone, climate risk, environmental hazards, seismic |
| BLS | Employment + wage data |
| OpenStreetMap + Leaflet | Maps, geocoding, reverse geocoding |

Everything is rate-limited per user per month (RentCast caps at 40 calls, with reset date + usage returned in response headers), and each source has a graceful fallback when it's down or quota runs out.

### Search that isn't dumb

- Listings are ranked with a weighted score: location 0.30, price 0.25, size 0.20, type 0.15, recency 0.10 (with exponential decay — new=1.0, week=0.8, month=0.5, older=0.2). User behavior (views, searches, saves) is merged into a rolling profile — [`frontend/js/recommendation-engine.js`](./frontend/js/recommendation-engine.js).
- The chat AI does intent classification and entity extraction (price / city / bedrooms / house type) via OpenAI, with a pure-regex fallback when the LLM is unreachable — [`frontend/ai-chat.js`](./frontend/ai-chat.js).
- City autocomplete runs against a 43,000-city dataset with debounced fuzzy matching — [`backend/autocomplete.js`](./backend/autocomplete.js).

### The negotiation AI doesn't lowball on message one

The negotiator moves through eight conversation phases:

```
INTRO -> RAPPORT -> QUALIFICATION -> AVAILABILITY
      -> PRICE INTRO -> ACTIVE NEGOTIATION -> COUNTER -> ACCEPTANCE
```

Each turn builds a system prompt dynamically — current phase goals, extracted property features, tenant budget, inferred landlord personality, the last 8 messages. Phase transitions fire on keyword detection and message count, so it feels like a conversation rather than an aggressive bot.

### Chat, notifications, and everything real-time

- Supabase Realtime subscriptions for messages, notifications, and negotiation updates — zero polling, the client state stays in sync as the database changes.
- File uploads (PDFs, docs, images) up to 5 MB with MIME validation, stored in a dedicated Supabase bucket.
- Conversation-read tracking with an RPC that bypasses RLS for counter updates.
- Floating messenger popup (Facebook-style) plus a dedicated chat panel for landlord inquiries.

Deep-dive: [`frontend/CHAT_SYSTEM_README.md`](./frontend/CHAT_SYSTEM_README.md).

### Market + property analytics

A set of analytics endpoints roll up per-listing and per-neighborhood numbers:

- **Investment view** — CAP rate, cash flow, ROI, break-even point, risk score.
- **Market view** — appreciation rate, rent growth, vacancy, turnover, seasonal variation, volatility.
- **Demographics** — age, household income, education, family status, population growth, stability index.
- **Projections** — 12-month price and rent projections, demand forecast, infrastructure score.
- **Sentiment** — 0–100 sentiment score with buyer / seller / investor / renter breakdown and predictive signals (search volume, inquiry rate, listing activity).

Code: analytics + sentiment routes in [`backend/server.js`](./backend/server.js).

---

## What's in the box

- **Instant auto-reply** — sub-60-second response to new inquiries, with intent classification (viewing / application / question / general) and human-like 800–1,200 ms delay so it doesn't feel robotic.
- **AI negotiator** — phased, human-paced rent negotiation with real-time landlord notification.
- **True cost calculator** — unified monthly total across rent, utilities, commute, insurance, and fees.
- **RoomPal** — roommate matching with lifestyle badges, compatibility scoring, and filter-driven discovery.
- **Real-time chat** — Supabase Realtime, file upload, read-receipt tracking.
- **Interactive maps** — Leaflet with marker clustering and OpenStreetMap geocoding.
- **Payments** — Stripe subscriptions + one-off charges.
- **Identity verification** — Azure Document Intelligence + Azure Face API for KYC.
- **Auth options** — Supabase Auth, Google OAuth, Apple Sign-In, email OTP (via Brevo), Turnstile CAPTCHA against bots.

---

## Architecture

```
        Web (vanilla JS)    iOS (SwiftUI)    Android (Java)
                \                |                /
                 \               |               /
                  +------- Express 5 API --------+
                           (Node 18, Railway)
                                  |
        +-------------------+-----+-----+--------------------+
        |                   |           |                    |
   Supabase               OpenAI   Cloudflare       Stripe + Brevo +
   Postgres + Auth         GPT    Workers AI        Azure (ID verify)
   + Realtime + RLS              (Vision LLM)
                                  |
                       15+ external data APIs
```

Where things live in the repo:

- `backend/` — Express 5 API, containerized on Node 18 Alpine, deployed on Railway.
- `frontend/` — 86 vanilla-JS modules organized by feature (auth, chat, listings, map, search, ui, utils).
- `cloudflare-worker/` — TypeScript Worker for vision inference.
- `database/migrations/` — 27 idempotent SQL migrations, row-level-security policies, the `listings_with_total_cost` view.
- `ai-learning/` — negotiation learning loop, pattern analyzer, template picker, success tracker, persisted dataset.
- `RoomFinderAI-IOS/` — native SwiftUI app (iOS 16+).
- `RoomFinderAndroid/` — native Java app (min API 24, target API 34).

---

## Stack

| Backend & data | Front-end & mobile | AI & services |
|---|---|---|
| Node 18 + Express 5 | Vanilla JS (modular) | OpenAI (chat + negotiation) |
| Supabase (Postgres + Auth + Realtime) | Tailwind CSS | Cloudflare Workers AI (Llama 3.2 11B Vision) |
| Docker (Node 18 Alpine) | Leaflet + marker clustering | Azure Document Intelligence + Face |
| Railway deployment | Supabase Realtime client | Stripe payments |
| Row-level security, bcrypt, JWT-ready | SwiftUI (iOS 16+) | Brevo transactional email |
| 27 SQL migrations | Java + Material 3 (Android, API 24+) | 15+ external data APIs |

---

## Run it locally

```bash
git clone https://github.com/redhasanh1/RoomFinderAI.git
cd RoomFinderAI/backend
npm install
cp ../.env.example ../.env    # fill in Supabase + OpenAI keys
npm run dev                    # http://localhost:3000
```

Full walkthrough with every optional service wired up: [`SETUP_GUIDE.md`](./SETUP_GUIDE.md).
Deployment guide: [`docs/RAILWAY_DEPLOYMENT.md`](./docs/RAILWAY_DEPLOYMENT.md).

---

## What's next

Pulled from [`TODO-PRODUCTION.md`](./TODO-PRODUCTION.md):

- **Sublease Finder** — short-term lease matching with partial-term pricing.
- **Mortgage Intelligence Hub** — affordability + rent-vs-buy on the same data pipeline.
- **RoomPal GA** — roommate matching with a compatibility-score model trained on engagement.
- **Student Housing Center** — university-proximity vertical with academic-calendar-aware pricing.

---

## Docs

- [`FEATURE_SUMMARY.md`](./FEATURE_SUMMARY.md) — instant response system + true cost calculator deep-dive
- [`IMPLEMENTATION_GUIDE.md`](./IMPLEMENTATION_GUIDE.md) — deployment + migration walkthrough
- [`docs/API_DOCUMENTATION.md`](./docs/API_DOCUMENTATION.md) — REST surface
- [`ai-learning/README.md`](./ai-learning/README.md) — the learning loop
- [`frontend/CHAT_SYSTEM_README.md`](./frontend/CHAT_SYSTEM_README.md) — real-time chat
- [`frontend/MAP_INTEGRATION_README.md`](./frontend/MAP_INTEGRATION_README.md) — Leaflet integration
- [`RoomFinderAI-IOS/README.md`](./RoomFinderAI-IOS/README.md) — iOS app
- [`RoomFinderAndroid/README.md`](./RoomFinderAndroid/README.md) — Android app

---

## License

MIT. See [`backend/package.json`](./backend/package.json).

**Hasan Iqbal** — [github.com/redhasanh1](https://github.com/redhasanh1) — hasaniqbal2@hotmail.com
