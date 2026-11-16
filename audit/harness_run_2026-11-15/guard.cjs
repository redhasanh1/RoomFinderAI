/**
 * Preload for scripts/negotiation_battle.js. Loaded with `node -r`, so the
 * harness itself runs unmodified.
 *
 *  1. Answers the harness's Supabase listings request with fixture_listings.json,
 *     so no production data is read.
 *  2. Lets requests through only to the local backend (HARNESS_ALLOWED_ORIGIN).
 *     Any other URL throws.
 *  3. Budget guard: adds up tokensUsed from each response and prices every
 *     token at gpt-3.5-turbo's output rate ($1.50 per 1M), which overstates
 *     the cost on purpose. Exits with code 3 before any request that would
 *     start with the estimate at or above BUDGET_CAP_USD.
 *  4. Writes one JSON line per call to calls.jsonl.
 */
'use strict';
const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const FIXTURES = JSON.parse(fs.readFileSync(path.join(DIR, 'fixture_listings.json'), 'utf8'));
const FIXTURE_ORIGIN = process.env.SUPABASE_URL;            // dummy, e.g. http://fixture.invalid
const ALLOWED = process.env.HARNESS_ALLOWED_ORIGIN;         // http://127.0.0.1:3999
const CAP = Number(process.env.BUDGET_CAP_USD || 2.75);
const PRICE_PER_TOKEN = 1.5 / 1e6;                           // conservative: output rate for all tokens
const MISSING_TOKENS_ASSUMED = 3000;                         // if a response omits tokensUsed
const LOG = path.join(DIR, 'calls.jsonl');

if (!FIXTURE_ORIGIN || !ALLOWED) {
    console.error('guard: SUPABASE_URL (dummy) and HARNESS_ALLOWED_ORIGIN must be set');
    process.exit(2);
}

const realFetch = global.fetch;
let calls = 0;
let tokens = 0;
let costUsd = 0;

function log(entry) { fs.appendFileSync(LOG, JSON.stringify(entry) + '\n'); }

global.fetch = async function guardedFetch(input, init) {
    const url = String(typeof input === 'string' ? input : input.url);

    if (url.startsWith(FIXTURE_ORIGIN)) {
        log({ ts: new Date().toISOString(), kind: 'fixture_listings', url: url.replace(FIXTURE_ORIGIN, '<fixture>') });
        return new Response(JSON.stringify(FIXTURES), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }
    if (!url.startsWith(ALLOWED)) {
        throw new Error(`guard: blocked request to non-local URL ${new URL(url).origin}`);
    }
    if (costUsd >= CAP) {
        console.error(`guard: BUDGET CAP reached (est $${costUsd.toFixed(4)} >= $${CAP}). Aborting.`);
        log({ ts: new Date().toISOString(), kind: 'budget_abort', calls, tokens, est_cost_usd: costUsd });
        process.exit(3);
    }

    const t0 = Date.now();
    const res = await realFetch(input, init);
    const ms = Date.now() - t0;
    let used = null;
    try { used = (await res.clone().json())?.tokensUsed ?? null; } catch (_) { /* non-JSON */ }
    const counted = Number.isFinite(used) && used > 0 ? used : MISSING_TOKENS_ASSUMED;
    calls += 1;
    tokens += counted;
    costUsd += counted * PRICE_PER_TOKEN;
    log({
        ts: new Date().toISOString(), kind: 'llm_call', endpoint: new URL(url).pathname,
        status: res.status, ms, tokensUsed: used, tokens_counted: counted,
        cum_calls: calls, cum_tokens: tokens, cum_est_cost_usd: Number(costUsd.toFixed(5))
    });
    return res;
};

process.on('exit', (code) => {
    const summary = { calls, tokens_counted: tokens, est_cost_usd_conservative: Number(costUsd.toFixed(4)), cap_usd: CAP, exit_code: code };
    fs.writeFileSync(path.join(DIR, 'guard_summary.json'), JSON.stringify(summary, null, 2));
});
