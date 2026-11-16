/**
 * Server-process preload (node -r). No server source file is changed.
 *
 *  1. In any request to api.openai.com/v1/chat/completions, rewrites
 *     model "gpt-3.5-turbo" to "gpt-4o-mini". gpt-3.5-turbo has been
 *     deprecated, and /api/landlord-simulator hard-codes it.
 *  2. Blocks any request to api.groq.com, so no call can quietly fall back
 *     to Groq. GROQ_API_KEY is also left blank at launch.
 *  3. Records the real prompt and completion tokens from each OpenAI
 *     response's `usage` field in server_llm_calls.jsonl.
 *  4. Budget guard on real tokens: before each OpenAI call, refuses the call
 *     if the conservatively priced running total is at or above
 *     BUDGET_CAP_USD. The conservative price is gpt-3.5-turbo's
 *     ($0.50 in / $1.50 out per 1M), higher than gpt-4o-mini's.
 */
'use strict';
const fs = require('fs');
const path = require('path');

const LOG = path.join(__dirname, 'server_llm_calls.jsonl');
const SUMMARY = path.join(__dirname, 'server_llm_summary.json');
const CAP = Number(process.env.BUDGET_CAP_USD || 2.75);
const SWAP_FROM = 'gpt-3.5-turbo';
const SWAP_TO = 'gpt-4o-mini';
// gpt-4o-mini list price (USD per 1M tokens), used for the reported actual cost. Check it on the OpenAI pricing page.
const PRICE_ACTUAL = { in: 0.15, out: 0.60 };
// Conservative price used only by the cap check.
const PRICE_CAP = { in: 0.50, out: 1.50 };

const realFetch = global.fetch;
const tot = { calls: 0, ok: 0, failed: 0, blocked_groq: 0, swapped: 0, prompt_tokens: 0, completion_tokens: 0, models_seen: {} };
const cost = (p) => (tot.prompt_tokens * p.in + tot.completion_tokens * p.out) / 1e6;
const writeSummary = () => fs.writeFileSync(SUMMARY, JSON.stringify({
    ...tot,
    actual_cost_usd_gpt4o_mini_list: +cost(PRICE_ACTUAL).toFixed(4),
    conservative_cost_usd_cap_pricing: +cost(PRICE_CAP).toFixed(4),
    cap_usd: CAP
}, null, 2));

global.fetch = async function swapFetch(input, init = {}) {
    const url = String(typeof input === 'string' ? input : input.url);

    if (url.includes('api.groq.com')) {
        tot.blocked_groq++;
        fs.appendFileSync(LOG, JSON.stringify({ ts: new Date().toISOString(), kind: 'groq_blocked' }) + '\n');
        writeSummary();
        throw new Error('model_swap: Groq disabled for this run');
    }

    if (url.startsWith('https://api.openai.com/v1/chat/completions')) {
        if (cost(PRICE_CAP) >= CAP) {
            fs.appendFileSync(LOG, JSON.stringify({ ts: new Date().toISOString(), kind: 'budget_refused', conservative_cost: cost(PRICE_CAP) }) + '\n');
            throw new Error(`model_swap: budget cap $${CAP} reached`);
        }
        let body = {};
        try { body = JSON.parse(init.body); } catch (_) { /* leave as-is */ }
        const requested = body.model;
        if (requested === SWAP_FROM) { body.model = SWAP_TO; tot.swapped++; }
        init = { ...init, body: JSON.stringify(body) };

        const t0 = Date.now();
        const res = await realFetch(input, init);
        const ms = Date.now() - t0;
        let usage = null, returnedModel = null, err = null;
        try {
            const j = await res.clone().json();
            usage = j.usage || null; returnedModel = j.model || null; err = j.error?.message || null;
        } catch (_) { /* non-JSON */ }
        tot.calls++;
        res.ok ? tot.ok++ : tot.failed++;
        if (usage) { tot.prompt_tokens += usage.prompt_tokens || 0; tot.completion_tokens += usage.completion_tokens || 0; }
        if (returnedModel) tot.models_seen[returnedModel] = (tot.models_seen[returnedModel] || 0) + 1;
        fs.appendFileSync(LOG, JSON.stringify({
            ts: new Date().toISOString(), kind: 'openai_call', requested_model: requested, sent_model: body.model,
            returned_model: returnedModel, status: res.status, ms, max_tokens: body.max_tokens, temperature: body.temperature,
            prompt_tokens: usage?.prompt_tokens ?? null, completion_tokens: usage?.completion_tokens ?? null,
            error: err ? String(err).slice(0, 200) : null
        }) + '\n');
        writeSummary();
        return res;
    }

    return realFetch(input, init);
};

writeSummary();
