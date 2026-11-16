# Harness run 2026-11-15: no usable results

**Status: FAILED. 0 of 30 conversations produced a reply. No failure rates or deal rate can be reported from this run.**

| Item | Value |
|---|---|
| Commit | `d92ce563c55ef4c04692d7603ae3d2f293e63401` (no tracked files modified; only `audit/` is untracked) |
| Harness | `scripts/negotiation_battle.js`, sha256 `52dc7828…bc66` (unmodified) |
| Harness command | `SITE=http://127.0.0.1:3999 SUPABASE_URL=http://fixture.invalid SUPABASE_ANON=fixture HARNESS_ALLOWED_ORIGIN=http://127.0.0.1:3999 BUDGET_CAP_USD=2.75 node -r ./audit/harness_run_2026-11-15/guard.cjs scripts/negotiation_battle.js --iterations 30 --concurrency 1` |
| Server command | see `manifest.json` (port 3999, Supabase/Brevo/Stripe blank, `NEGOTIATOR_DAEMON=off`, `NODE_ENV=development`, `AI_PROVIDER=auto`) |
| Safeguards confirmed in `server.log` | "Supabase not initialized", "negotiator daemon disabled", "Skipping Brevo API test"; `/health` reported supabase:false, stripe:false |
| Conversations attempted / succeeded | 30 / **0** |
| LLM requests sent to the local server | 30 (all `POST /api/negotiate/phase-message`, all HTTP 500); the landlord simulator was never reached |
| Wall time | 9 s |
| Spend | **About $0.** All 30 responses had `tokensUsed: null`, because every provider rejected the request before generating anything. The guard's $0.135 is the placeholder it charges when a response has no token count (3,000 tokens per call), not a real charge. Confirm the actual figure on the OpenAI usage page. |

## Why every call failed (from `server.log`, 30 of each)

1. `openai (gpt-3.5-turbo)`: "The model `gpt-3.5-turbo` has been deprecated"
2. `groq (llama-3.1-8b-instant)`: "does not exist or you do not have access to it"
3. `groq (llama-3.3-70b-versatile)`: "does not exist or you do not have access to it"

Each of the 30 requests fell through the whole chain: OpenAI, then Groq 8b, then Groq 70b. Each attempt is logged.

## What this means

- **The approved configuration (option B, tenant on `gpt-3.5-turbo`) can't run.** OpenAI no longer serves that model.
- **`/api/landlord-simulator` would also fail.** It hard-codes `gpt-3.5-turbo` at `backend/server.js:6107`. The harness can't run at all until that line changes, and that is a server-code edit, which was not authorised.
- **Production may be affected too.** If Railway has the same `OPENAI_MODEL=gpt-3.5-turbo` and the same Groq key as the local `.env`, every AI negotiation call in production returns 500. The server's built-in default is also `gpt-3.5-turbo` (`server.js:94`, `7634`). This hasn't been verified: check Railway's variables and logs.

## Rates

None. With 0 successful conversations, every metric has an empty denominator. `analyze.cjs` is in this folder, ready for a later run.

## Files

- `battle-2026-11-16T02-36-55-675Z.json`: raw harness output (30 error entries)
- `harness_stdout.log`, `server.log`, `calls.jsonl`, `guard_summary.json`, `manifest.json`
- `fixture_listings.json`, `guard.cjs`, `analyze.cjs`
