# RoomFinderAI

**An AI-powered rental marketplace with a data-driven negotiation engine, market-intelligence pipeline, and a closed-loop learning system.**

[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![Express](https://img.shields.io/badge/Express-5.1-000000?logo=express&logoColor=white)](https://expressjs.com/)
[![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%7C%20Auth%20%7C%20Realtime-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com/)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT-412991?logo=openai&logoColor=white)](https://openai.com/)
[![Cloudflare Workers AI](https://img.shields.io/badge/Cloudflare%20Workers%20AI-Llama%203.2%20Vision-F38020?logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/workers-ai/)
[![Stripe](https://img.shields.io/badge/Stripe-Payments-635BFF?logo=stripe&logoColor=white)](https://stripe.com/)
[![Railway](https://img.shields.io/badge/Deployed%20on-Railway-0B0D0E?logo=railway&logoColor=white)](https://railway.app/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](#license)

RoomFinderAI is a full-stack rental platform (web + native iOS + native Android) that rethinks the renter experience around three ideas: **transparent total-cost economics**, **sub-60-second response times**, and **an adaptive negotiation AI that learns from every conversation**. The repo spans a data pipeline, analytics engine, recommendation system, LLM negotiation agent, computer-vision pricing model, and 15+ integrated third-party data sources — all wired into a single product.

---

## At a glance

| | |
|---|---|
| **Negotiations analyzed in the learning pipeline** | **1,247** |
| **Response templates tracked with A/B-style performance data** | **22** (top template: 82% success over 45 samples) |
| **External data sources fused into market intelligence** | **15+** (RentCast, Walk Score, GreatSchools, FBI Crime, FEMA, EPA, NOAA, BLS, USGS, Google Distance Matrix, …) |
| **REST endpoints** | **60+** across listings, auth, AI, payments, analytics, verification |
| **SQL migrations** | **27** in `database/migrations/` |
| **Frontend modules** | **86** vanilla-JS modules + 26 HTML pages |
| **Native apps sharing one backend** | **iOS (SwiftUI)** + **Android (Java / Material 3)** |
| **Auto-response baseline vs. industry** | **< 60s** vs. Zillow's 12–48h |

---

## Data & analytics

> The primary engineering bet in this project is that **rental decisions are really data problems** — cost transparency, market comparables, and response-time analytics — with AI as the delivery vehicle.

### Market Intelligence Pipeline

A single `/api/market-intelligence`-adjacent surface fuses fifteen external data sources into per-listing, per-neighborhood context:

| Domain | Source | What it adds |
|---|---|---|
| Valuations & comps | RentCast | Rent estimates, sales comps, market stats |
| Mobility | Walk Score, Google Distance Matrix | Walkability, commute minutes + cost |
| Education | GreatSchools | School ratings by address |
| Safety | FBI Crime API | Crime statistics by geography |
| Climate & hazards | FEMA, NOAA, EPA, USGS | Flood zones, weather risk, environmental hazards, seismic activity |
| Economy | BLS | Employment + wage data |
| Geospatial | OpenStreetMap Nominatim, Leaflet, Google Maps | Geocoding, reverse geocoding, map rendering |

Rate-limiting is per-user/per-month (see `backend/server.js` RentCast rate-limit store: 40 calls/month), with reset-date calculation, usage headers returned in responses, and graceful fallback when a source is unavailable.

### Negotiation Learning System — closed loop

End-to-end implementation in `ai-learning/`:

```
event capture  ->  pattern extraction  ->  Bayesian-weighted correlation update
     ^                                                     |
     |                                                     v
   outcome <-  epsilon-greedy template selection  <-  template weights
```

- **Pattern analyzer** (`ai-learning/core/pattern-analyzer.js`) extracts success patterns by **message length**, **response timing**, **price strategy**, **landlord personality**, **time-of-day**, and **seasonality**. Examples from the dataset: 20–80 char messages win 72% of the time; replies under 30 min win 78%; market-rate offers (95–105% of ask) win 85%.
- **Template optimizer** (`ai-learning/optimizers/template-optimizer.js`) uses an **epsilon-greedy** strategy (80% exploit / 20% explore) with context multipliers for landlord personality, market conditions, and price range.
- **Success tracker** (`ai-learning/analyzers/success-tracker.js`) logs every negotiation, computes rolling success rates, and feeds per-template weights back into selection.
- **Persisted dataset** (`ai-learning/data/`): `success-patterns.json` + `template-performance.json` — 1,247 negotiations, 22 templates, per-template sample size, success rate, and average savings.

### True Cost Model

Rent alone is a lie. The `True Cost Calculator` — documented in [`FEATURE_SUMMARY.md`](./FEATURE_SUMMARY.md) and implemented in `backend/server.js` + migration [`001_add_true_cost_fields.sql`](./database/migrations/001_add_true_cost_fields.sql) — blends:

- **Commute**: Google Distance Matrix API, with driving at the 2026 IRS rate of $0.67/mile, transit tiered by distance, and biking/walking adjustments.
- **Utilities**: parametric estimate by property type × bedrooms (apartments $80/br, houses $120/br, condos $90/br, studios $60).
- **Renters' insurance**: tiered by rent band.
- **Ancillary**: parking, internet, pet fees, amenity fees, all per-listing overrides.

Exposed as a denormalized `listings_with_total_cost` SQL view so the calculator can sort, filter, and paginate at the database layer.

### Property Analytics Engine

Server-side analytics endpoints (`backend/server.js` — analytics & sentiment routes) compute per-property and per-market:

- **Investment metrics** — CAP rate, cash flow, ROI, break-even point, risk score.
- **Market metrics** — appreciation rate, rent growth, vacancy, turnover, seasonal variation, volatility.
- **Demographics** — age bands, household income, education, family status, population growth, stability index.
- **Projections** — 12-month price and rent projections, demand forecast, infrastructure score.
- **Sentiment** — 0–100 sentiment score with buyer/seller/investor/renter breakdown + predictive signals (search volume, inquiry rate, listing activity).

### User Activity & Conversion Analytics

Every user action logs to a structured activity stream (`registered`, `ai_negotiation_assistant`, `ai_chat`, `subscription_bought`, `id_submitted`, `selfie_submitted`, …). The [`response_analytics`](./database/migrations/002_add_instant_response_tables.sql) table tracks the inquiry-to-viewing funnel: auto-response latency, human follow-up latency, conversion rates per landlord, per-listing, and per-template.

---

## AI / ML engineering

### LLM prompt engineering — 8-phase negotiation state machine

`frontend/ai-negotiation.js` + `backend/server.js` (`/api/ai-negotiate`) implement a conversation state machine with eight phases:

```
INTRODUCTION -> RAPPORT_BUILDING -> QUALIFICATION -> AVAILABILITY_DISCUSSION
              -> PRICE_INTRODUCTION -> ACTIVE_NEGOTIATION
              -> COUNTER_OFFER -> ACCEPTANCE
```

For every turn, the system builds a dynamic system prompt that injects:
- the current phase's conversational goals,
- extracted property features (15+ types: renovations, views, spacious, design, etc.),
- tenant budget and qualifications,
- inferred landlord personality (cooperative / professional / aggressive / casual),
- the last 8 messages of conversation history.

Temperature, presence penalty, and frequency penalty are tuned per phase. Phase transitions are triggered by keyword detection and message count, avoiding the robotic "instant lowball" pattern that kills most auto-negotiators.

### Recommendation Engine — weighted multi-factor scoring

`frontend/js/recommendation-engine.js` implements a 5-factor scoring model:

| Factor | Weight | Signal |
|---|---:|---|
| Location | 0.30 | Fuzzy-match on user's searched / saved cities, frequency-weighted |
| Price | 0.25 | Range-based with penalty for above-budget listings |
| Size | 0.20 | Bedroom preference with Euclidean fallback |
| Type | 0.15 | Property-type preference weighting |
| Recency | 0.10 | Exponential decay (new=1.0, week=0.8, month=0.5, older=0.2) |

User behavior (views, searches, saves) is captured to `localStorage` / IndexedDB and a Supabase-backed cache, then merged into a rolling behavior profile. Output: ranked listings with explicit "why this matched" reasons.

### Computer Vision — Llama 3.2 11B Vision on Cloudflare Workers AI

`cloudflare-worker/src/index.ts` ships a vision inference worker that takes property photos and returns a structured `PropertyAnalysis`:

- **Luxury score** (1–10) and **unit grade** (A+ to C-).
- **Money features** detected (granite, stainless steel, hardwood, exposed brick, …) with per-feature $ value impact.
- **Flaws and staging issues** with improvement suggestions.
- **Suggested price**: base rent by type × location multiplier + feature premium + luxury bonus − flaw penalty.
- **Target demographic** and **FOMO marketing copy** generated inline.

Uses Cloudflare's edge GPU inference so image analysis stays sub-second and doesn't block the Express API.

### NLP — intent classification + entity extraction

Two-tier extraction (`frontend/ai-chat.js`, `backend/server.js` `/api/chat`):

1. **Primary path** — LLM call with structured JSON-output system prompt that extracts `{ intent, price, city, bedrooms, house_type }` and routes to `search` / `negotiate` / `chat`.
2. **Fallback path** — pure-regex extraction for when the LLM is unavailable or rate-limited: price regex, 50+ city dictionary, bedroom regex, 7-way house-type classifier.

This dual-path design means the chat experience degrades gracefully to deterministic behavior rather than failing when API quotas hit.

### Adaptive experimentation

The learning engine's epsilon-greedy selector doesn't just pick the highest-observed-success template — it explicitly allocates 20% of traffic to exploration, weighted by context multipliers. Sample sizes, success rates, and avg-savings are updated in the same transaction, keeping selection honest against cold-start bias.

---

## Architecture

```
                           Web (vanilla JS + Tailwind + Leaflet)
                                           |
                   iOS (SwiftUI)  ---------+---------  Android (Java / Material 3)
                                           |
                                           v
                              +---------------------------+
                              |   Express 5 API (Node 18) |
                              |   60+ endpoints           |
                              +--------------+------------+
                                             |
              +-----------------+------------+------------+-----------------+
              |                 |            |            |                 |
              v                 v            v            v                 v
     Supabase (Postgres +   OpenAI       Cloudflare    Azure Vision +    Stripe +
     Auth + Realtime + RLS) GPT          Workers AI    Face API          Brevo Email
     27 migrations          (negotiation)  (Llama 3.2    (ID verify)    (payments +
     RLS-enforced                           Vision)                       transactional email)

                                           |
                                           v
                 15+ external data APIs (RentCast, Walk Score, GreatSchools,
                 FBI Crime, FEMA, EPA, NOAA, BLS, USGS, Google Distance Matrix, …)
```

Layer map:

- `backend/` — Express 5 monolithic API, containerized Node 18 Alpine, deployed on Railway.
- `frontend/` — 86 vanilla-JS modules organized by feature (auth / chat / listings / map / search / ui / utils).
- `cloudflare-worker/` — TypeScript Worker for vision inference.
- `database/migrations/` — 27 idempotent SQL migrations, RLS policies, the `listings_with_total_cost` view.
- `ai-learning/` — learning engine, pattern analyzer, template optimizer, success tracker, persisted datasets.
- `RoomFinderAI-IOS/` — native SwiftUI app (iOS 16+), shares backend.
- `RoomFinderAndroid/` — native Java app (min API 24, target API 34), shares backend.

---

## Tech stack

| Frontend | Backend & Data | AI, ML & Vision |
|---|---|---|
| Vanilla JS (modular) | Node 18 + Express 5 | OpenAI (GPT) for negotiation + chat |
| Tailwind CSS | Supabase (Postgres + Auth + Realtime) | Cloudflare Workers AI (Llama 3.2 11B Vision) |
| Leaflet.js + marker clustering | Stripe (payments) | Azure Document Intelligence + Face API (ID verify) |
| Supabase Realtime client | Brevo (transactional email) | Custom learning engine (epsilon-greedy) |
| SwiftUI (iOS 16+) | Azure Document / Face APIs | Custom recommendation engine (weighted scoring) |
| Java + Material 3 (Android) | Docker (Node 18 Alpine) | 15+ external data APIs |
| Google OAuth + Apple Sign-In | Railway deployment + health checks | RentCast market model |

---

## Feature highlights

- **Instant AI Response** — sub-60-second auto-reply to new inquiries with intent classification (viewing / application / question / general), human-like 800–1,200 ms delay, and one-time-per-conversation trigger. See [`FEATURE_SUMMARY.md`](./FEATURE_SUMMARY.md).
- **AI Negotiator** — phased, human-like rent negotiation with real-time landlord notification and Supabase-channel success alerts.
- **True Cost Calculator** — unified monthly total across rent, utilities, commute, insurance, and fees.
- **RoomPal** — roommate matching with lifestyle badges and compatibility scoring.
- **Real-time chat** — Supabase Realtime subscriptions, file upload (5 MB limit, configurable), conversation-read tracking. See [`frontend/CHAT_SYSTEM_README.md`](./frontend/CHAT_SYSTEM_README.md).
- **Interactive maps** — Leaflet with marker clustering and Nominatim geocoding. See [`frontend/MAP_INTEGRATION_README.md`](./frontend/MAP_INTEGRATION_README.md).
- **Stripe payments** — subscription + one-off charge flows.
- **Azure ID verification** — Document Intelligence + Face API for KYC.

Full API surface: [`docs/API_DOCUMENTATION.md`](./docs/API_DOCUMENTATION.md).

---

## Getting started

```bash
git clone https://github.com/connorwilson365/RoomFinderAI.git
cd RoomFinderAI
cd backend && npm install
cp ../.env.example ../.env    # fill in Supabase + OpenAI keys
npm run dev                    # http://localhost:3000
```

Full walkthrough with every optional service wired up: [`SETUP_GUIDE.md`](./SETUP_GUIDE.md).
Railway deployment guide: [`docs/RAILWAY_DEPLOYMENT.md`](./docs/RAILWAY_DEPLOYMENT.md).

---

## Skills demonstrated

**Data / analytics**
- SQL schema design and migration authoring (27 migrations, RLS policies, denormalized views)
- Data pipeline design — external-API ingestion, rate-limit budgeting, graceful degradation
- Analytics surface design — CAP rate, ROI, sentiment, demographic breakdowns, funnel analytics
- Unified cost modeling (commute + utilities + insurance + fees)

**AI / ML engineering**
- LLM prompt engineering — multi-phase system prompts, dynamic context injection, temperature / presence tuning
- Recommendation systems — multi-factor weighted scoring with temporal decay
- Adaptive experimentation — epsilon-greedy with context multipliers and cold-start handling
- Computer vision — vision-LLM inference for feature extraction and pricing
- NLP — intent classification and entity extraction with deterministic fallback

**Full-stack delivery**
- Web + native iOS + native Android sharing a single API
- Real-time systems — Supabase Realtime subscriptions, WebSockets, push notifications
- Auth — Supabase Auth, Google OAuth, Apple Sign-In, email OTP, JWT-ready
- Payments — Stripe subscriptions + one-off
- Production deployment — Railway, Docker, health checks, service-status monitoring
- Security — RLS policies, bcrypt, HTTPS, CORS, Turnstile CAPTCHA, Azure KYC

---

## Roadmap

Drawn from [`TODO-PRODUCTION.md`](./TODO-PRODUCTION.md):

- **Sublease Finder** — short-term lease matching with partial-term pricing.
- **Mortgage Intelligence Hub** — affordability and rent-vs-buy modeling layered on the same data pipeline.
- **RoomPal GA** — roommate matching with compatibility-score model trained on engagement outcomes.
- **Student Housing Center** — university-proximity vertical with academic-calendar-aware pricing.

---

## Documentation index

- [Feature deep-dive](./FEATURE_SUMMARY.md) — Instant AI Response + True Cost Calculator
- [Implementation guide](./IMPLEMENTATION_GUIDE.md) — deployment + migration walkthrough
- [Setup guide](./SETUP_GUIDE.md) — full service wiring
- [API documentation](./docs/API_DOCUMENTATION.md) — REST surface
- [Chat system](./frontend/CHAT_SYSTEM_README.md) — real-time messaging module
- [Map integration](./frontend/MAP_INTEGRATION_README.md) — Leaflet integration
- [AI learning system](./ai-learning/README.md) — negotiation learning loop
- [iOS app](./RoomFinderAI-IOS/README.md) — native SwiftUI client
- [Android app](./RoomFinderAndroid/README.md) — native Java client
- [Railway deployment](./docs/RAILWAY_DEPLOYMENT.md) — production deploy

---

## License

MIT — see [`backend/package.json`](./backend/package.json).

## Contact

**Connor Wilson** · [github.com/connorwilson365](https://github.com/connorwilson365) · connorwilson365@yahoo.com
