# Negotiation harness run, 2026-11-15 (attempt 2, gpt-4o-mini)

**Sample size warning: N = 30 conversations, a small sample.** For a rate near 50%, the 95% margin of error is about ±18 points. Every rate below comes with a Wilson 95% interval.

## Run identity

| Item | Value |
|---|---|
| Commit | `d92ce563c55ef4c04692d7603ae3d2f293e63401` (no tracked file modified; only `audit/` is untracked; nothing committed) |
| Harness | `scripts/negotiation_battle.js`, unmodified, sha256 `52dc7828867d6804454dfa1a96e012611cc772354e6a8cae9515aa9aa0a2bc66` |
| Harness command | `SITE=http://127.0.0.1:3999 SUPABASE_URL=http://fixture.invalid SUPABASE_ANON=fixture HARNESS_ALLOWED_ORIGIN=http://127.0.0.1:3999 BUDGET_CAP_USD=2.75 node -r ./audit/harness_run_2026-11-15/guard.cjs scripts/negotiation_battle.js --iterations 30 --concurrency 1` |
| Server command | `PORT=3999 NODE_ENV=development NEGOTIATOR_DAEMON=off AI_PROVIDER=auto ENABLE_DEMO_MODE=false SUPABASE_URL= SUPABASE_ANON_KEY= SUPABASE_SERVICE_ROLE_KEY= BREVO_API_KEY= STRIPE_SECRET_KEY= STRIPE_WEBHOOK_SECRET= GROQ_API_KEY= BUDGET_CAP_USD=2.75 SELF_BASE_URL=http://127.0.0.1:3999 node -r ./audit/harness_run_2026-11-15/model_swap.cjs backend/server.js` |
| Models | Tenant and landlord both **gpt-4o-mini** (`gpt-4o-mini-2024-07-18` on all 408 responses). The server asked for `gpt-3.5-turbo`, and `model_swap.cjs` rewrote that in every request. Groq was off: no key, and blocked in the preload. Groq attempts: 0. |
| Seed / determinism | The harness uses no random numbers: listing = i % 12 fixtures, goal template = i % 3, landlord persona = i % 4. LLM sampling is **not** seeded (tenant temperature 0.8, or 0.3 in CLOSING; landlord 0.85), so the transcripts won't be reproduced exactly. |
| Data | 12 fixture listings from `database/sql/seed-test-data.sql`. No production database was read or written: Supabase was off, and the daemon was off. |
| Wall time | 298 s |

## Spend (real token counts)

| | Value |
|---|---|
| OpenAI calls | 408 (219 tenant `phase-message` + 189 `landlord-simulator`), all HTTP 200, 0 failed |
| Tokens | 258,402 prompt + 8,149 completion = 266,551 |
| **Actual cost** | **$0.0436** at gpt-4o-mini list price ($0.15 in / $0.60 out per 1M; check on the OpenAI pricing page) |
| Cap-check estimate | $0.14 (server guard, gpt-3.5 prices) / $0.40 (harness guard, $1.50/1M flat). Both far under the $2.75 cap. |
| Attempt 1 (gpt-3.5-turbo, all rejected) | about $0, no tokens generated. Files in `attempt1_failed_gpt-3.5/`. |

## Per-conversation rates (denominator = conversations, n = 30 unless stated)

| Metric | k / n | Rate | 95% CI (Wilson) | ± |
|---|---|---|---|---|
| Deal rate, harness definition (`deal_closed`) | 30 / 30 | 100% | 88.6 to 100% | 5.7 |
| Deal rate, strict (agreed price pinned, no `closed_without_acceptance`) | 23 / 30 | 76.7% | 59.1 to 88.2% | 14.6 |
| Meeting agreed before price: rubric `closed_without_price_discussion` | 0 / 30 | 0% | 0 to 11.4% | 5.7 |
| Meeting agreed before price: transcript check (any tenant reply matching the server validator's day + affirm patterns before any price) | 0 / 30 | 0% | 0 to 11.4% | 5.7 |
| Deals settled too high: rubric `agreed_significantly_above_target` (agreed > listing − target reduction + $75), of priced deals | 7 / 23 | 30.4% | 15.6 to 50.9% | 17.6 |
| Deals above the tenant's target at all (no $75 allowance), of priced deals | 13 / 23 | 56.5% | 36.8 to 74.4% | 18.8 |
| Deals at or above the listing price, of priced deals | 0 / 23 | 0% | 0 to 14.3% | n/a |
| Deals above budget (`agreed_above_budget`; only set for listings over $2,500) | 0 / 5 | 0% | 0 to 43.4% | 21.7 |
| Accepted a day outside the tenant's availability | 3 / 30 | 10.0% | 3.5 to 25.6% | 11.1 |
| Tenant repeated itself | 20 / 30 | 66.7% | 48.8 to 80.8% | 16.0 |
| Hit the 18-turn limit | 2 / 30 | 6.7% | 1.8 to 21.3% | 9.7 |

Priced deals got a mean rent reduction of 5.9% off the listing price (median 7.1%). The harness's average score was 0.78, with an average of 14 messages per conversation.

**Why the harness says 100% deals.** `deal_closed` is true whenever a conversation ends in CLOSING and either a price was agreed or the landlord mentioned any day or meeting word. 7 "closed" conversations had no agreed price and carry `closed_without_acceptance`. The strict 76.7% is the better figure to quote.

## Per-reply rates (denominator = tenant replies)

| Metric | k / n | Rate | 95% CI (Wilson) | Note |
|---|---|---|---|---|
| CLOSING-phase tenant replies affirming a meeting with no price yet discussed | 0 / 103 | 0% | 0 to 3.6% | 103 replies from all 30 conversations |
| All tenant replies affirming a meeting with no price yet discussed | 0 / 219 | 0% | 0 to 1.7% | |

Replies within one conversation aren't independent. The Wilson bound treats them as if they were, so it is too narrow. The resampling check that respects conversation grouping returns [0, 0], which tells you nothing when every count is zero. With conversations as the unit, a zero count out of 30 gives an upper bound of about 10–11%. Read the per-reply zero as "rare in this sample", not as a proven rate under 3.6%.

## These are rates after the server's guardrails

The run measured the whole server pipeline, guardrails included. The guardrails fired often (counts from `server.log`):

| Guardrail (`backend/server.js`) | Times fired |
|---|---|
| CLOSING gate: price never discussed, so the prompt switches back to a price question | 19 |
| Validator: AI accepted above target, so the reply is rewritten as a counter-offer (fires once per conversation) | 15 |
| Validator: AI agreed to a meeting before price, so the reply is rewritten | 2 |
| Validator: a CLOSING reply reopened utilities or the deposit, so it's rewritten | 1 |

So the 0% meeting-before-price results describe the shipped pipeline. They say nothing about the raw model. Without the guardrails, the model tried to affirm a meeting before price at least 2 times, and the CLOSING gate stepped in 19 more times before the model generated anything.

## How the new metrics map to the old code comments

| Old comment (`backend/server.js`) | Unit | New metric | How well it matches |
|---|---|---|---|
| "leak at **46%** of conversations at N=50" (meeting agreed before price) | conversation | 0 / 30 (CI 0–11.4%), rubric and transcript check | **Partial.** Same unit, and the same rubric issue probably fed it. But the old run's model, harness version and listings are unknown or different, and it was N=50. |
| "**56%** of CLOSING-phase replies affirming a meeting without price ever having been touched" | reply | 0 / 103 (CI 0–3.6%, too narrow; see above) | **Partial.** Same unit. The new figure re-implements the server validator's regexes on saved transcripts. How the old figure was computed isn't recorded. |
| "Harness at N=100 showed **71%** of post-iter5 deals settled too high" | deal | 30.4% (rubric, +$75 allowance) or 56.5% (any amount above target) | **Weak.** "Too high" isn't defined in the comment. The two plausible definitions give very different numbers. The 56.5% interval (36.8–74.4%) includes 71%. |
| (no old figure) deal rate | conversation | 76.7% strict / 100% harness definition | No old baseline exists. |

## Can an improvement be claimed?

- **Meeting before price (46% → 0/30):** the gap is far bigger than the noise. The upper bound of 11.4% is well below 46%. But it isn't a like-for-like comparison: different model (gpt-4o-mini; production's configured gpt-3.5-turbo no longer works), different harness version, fixture listings, and N=30 against N=50. A defensible statement: *"With the server-side guardrails, a 30-conversation simulated evaluation recorded 0/30 conversations agreeing to a meeting before price (95% CI 0–11%); an earlier N=50 run before the guardrails recorded 46%, under a different model and harness version."* **Don't** say "reduced from 46% to 0%" as a controlled result.
- **CLOSING affirmations (56% → 0/103):** the same caveats apply. Don't claim it as a controlled improvement.
- **Deals settled too high (71%):** **no claim.** The result depends on which definition you pick, and one of the two intervals includes 71%.
- **Deal rate:** no baseline exists, so there's no improvement to claim. 76.7% (CI 59–88%) is a level, not a change.

A controlled before/after needs the same model and harness, with the guardrails switched on and off, at a larger N. Switching them off would mean editing server code, which wasn't done.

## Production note (unverified)

Attempt 1 showed that `gpt-3.5-turbo` is deprecated and that this Groq key can't reach either Groq model. If Railway has the same settings, the live negotiator is failing. Check Railway's variables and logs. These results describe gpt-4o-mini, not what production serves today.

## Files

- `battle-2026-11-16T02-47-09-425Z.json`: raw harness output (30 transcripts and analyses)
- `metrics.json`: output of `node analyze.cjs battle-*.json`
- `server_llm_calls.jsonl` / `server_llm_summary.json`: one row per OpenAI call (model, status, real tokens, latency)
- `calls.jsonl` / `guard_summary.json`: harness-side call log and budget guard
- `harness_stdout.log`, `server.log`, `manifest.json`
- `guard.cjs`, `model_swap.cjs`, `analyze.cjs`, `fixture_listings.json`
- `attempt1_failed_gpt-3.5/`: the failed first attempt and its report

Before committing, the logs were scanned for keys and tokens (none found). The two Azure endpoint URLs printed at server startup were replaced with `<redacted-azure-endpoint>`, and the local checkout path with `<repo>`. No other content was changed.
