# RoomFinderAI

A rental marketplace that replies to inquiries in under 60 seconds, shows you the real monthly cost of a place instead of just the rent, and helps you negotiate with landlords using patterns learned from 1,247 past conversations.

Full-stack: Node/Express + Supabase Postgres backend, vanilla-JS web client, native iOS (SwiftUI) and Android (Java) apps — all sharing the same API.

[![Node.js](https://img.shields.io/badge/Node-18-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![Express](https://img.shields.io/badge/Express-5-000000?logo=express&logoColor=white)](https://expressjs.com/)
[![Supabase](https://img.shields.io/badge/Supabase-Postgres-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com/)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT-412991?logo=openai&logoColor=white)](https://openai.com/)
[![Cloudflare Workers AI](https://img.shields.io/badge/Workers%20AI-Llama%203.2%20Vision-F38020?logo=cloudflare&logoColor=white)](https://developers.cloudflare.com/workers-ai/)
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
- Time-of-day matters — 9–11 AM weekdays beats everything else.

The template selector is epsilon-greedy (80% exploit / 20% explore) with context multipliers for landlord personality and market conditions, so it keeps improving instead of collapsing onto whatever worked first.

Code: [`ai-learning/`](./ai-learning/) — the loop, the pattern extractor, the optimizer, and the persisted dataset.

### The real monthly cost of a place, not just the rent

Rent is the sticker price. The actual number is rent + utilities + commute + insurance + parking + pet fees + whatever else the listing hides. The platform computes all of that:

- **Commute** — Google Distance Matrix, driving at the 2026 IRS rate of $0.67/mile, transit tiered by distance.
- **Utilities** — parametric by property type and bedroom count.
- **Insurance** — tiered by rent band.
- **The total** — exposed as a `listings_with_total_cost` SQL view so sorting and filtering happen at the database layer, not in JS.

Why it matters: two listings at $1,800/month can easily differ by $400/month in true cost once you include a 45-minute commute and electric heat.

Code: [`backend/server.js`](./backend/server.js) + [`database/migrations/001_add_true_cost_fields.sql`](./database/migrations/001_add_true_cost_fields.sql). Deep-dive: [`FEATURE_SUMMARY.md`](./FEATURE_SUMMARY.md).

### Photos as a pricing signal

Listings get analyzed by Llama 3.2 11B Vision on Cloudflare Workers AI. The worker extracts money features (granite, stainless, hardwood, exposed brick, …), spots staging issues, grades the unit A+ to C-, and produces a suggested rent from a base × location-multiplier + feature premium − flaw penalty model. Runs on Cloudflare's edge GPU, so it stays off the main API's critical path.

Code: [`cloudflare-worker/src/index.ts`](./cloudflare-worker/).

### Fifteen external feeds, one surface

A listing isn't just a row in Postgres — it's joined at read-time with a pile of external context:

| | |
|---|---|
| RentCast | rent estimates, sales comps, market stats |
| Walk Score + Google Distance Matrix | walkability, commute time + cost |
| GreatSchools | school ratings by address |
| FBI Crime | neighborhood crime stats |
| FEMA, NOAA, EPA, USGS | flood zone, climate risk, environmental hazards, seismic |
| BLS | employment + wage data |
| OpenStreetMap + Leaflet | maps, geocoding, reverse geocoding |

All rate-limited per user per month, with graceful fallback when a source is down or quota is hit.

### The rest of the search does what you'd hope

- Listings are ranked with a weighted score: location 0.30, price 0.25, size 0.20, type 0.15, recency 0.10 (with exponential decay). User behavior (views, searches, saves) is merged into a rolling profile — [`frontend/js/recommendation-engine.js`](./frontend/js/recommendation-engine.js).
- The chat AI handles intent classification and entity extraction (price / city / bedrooms / house type) via OpenAI, with a pure-regex fallback when the LLM is unreachable — [`frontend/ai-chat.js`](./frontend/ai-chat.js).
- The negotiation AI moves through eight conversation phases (intro → rapport → qualification → availability → price intro → active → counter → acceptance) with phase-aware system prompts, so it doesn't immediately lowball the landlord in message one.

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

---

## Stack

**Backend:** Node 18, Express 5, Supabase (Postgres + Auth + Realtime), Docker, Railway
**Front-end:** Vanilla JS (modular), Tailwind, Leaflet, Supabase Realtime client
**Mobile:** SwiftUI (iOS 16+), Java + Material 3 (Android, min API 24)
**AI / data:** OpenAI, Cloudflare Workers AI (Llama 3.2 11B Vision), Azure Document Intelligence + Face, and 15 external data APIs

---

## Run it locally

```bash
git clone https://github.com/redhasanh1/RoomFinderAI.git
cd RoomFinderAI/backend
npm install
cp ../.env.example ../.env    # fill in Supabase + OpenAI keys
npm run dev                    # http://localhost:3000
```

Full walkthrough: [`SETUP_GUIDE.md`](./SETUP_GUIDE.md). Deployment: [`docs/RAILWAY_DEPLOYMENT.md`](./docs/RAILWAY_DEPLOYMENT.md).

---

## Docs

- [`FEATURE_SUMMARY.md`](./FEATURE_SUMMARY.md) — instant response system + true cost calculator deep-dive
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
