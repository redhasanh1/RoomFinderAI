#!/usr/bin/env node
/**
 * Recomputes the failure-rate metrics from the saved battle JSON. Makes no
 * network calls. Usage: node analyze.cjs battle-*.json > metrics.json
 *
 * Per-conversation metrics come from the harness's own analysis fields.
 * Per-reply metrics parse the transcripts, using the same regexes as the
 * server's validator (backend/server.js:7370-7371).
 */
'use strict';
const fs = require('fs');

const file = process.argv[2];
const { aggregate, results } = JSON.parse(fs.readFileSync(file, 'utf8'));
const ok = results.filter(r => !r.error);

// Same patterns as backend/server.js:7370-7371
const DAY = /\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|tonight|this weekend)\b/i;
const AFFIRM = /\b(works|sounds good|that works|see you|let.?s meet|let.?s do|will do|of course|absolutely)\b/i;
// Price detection, mirroring the server (AI said "$<digit>") and the harness's
// findFirstPrice for landlord messages (a 3-5 digit number, 100 to 50000).
const AI_PRICE = /\$\s*\d/;
function landlordPrice(text) {
    const m = String(text || '').match(/\$?\s*(\d{1,3}(?:[,]\d{3})+|\d{3,5})(?:\.\d{1,2})?/g);
    if (!m) return false;
    return m.some(raw => { const n = parseFloat(raw.replace(/[$,\s]/g, '')); return n >= 100 && n <= 50000; });
}

function parse(line) {
    const m = /^\[([A-Z_]+)\] (TENANT|LANDLORD): ([\s\S]*)$/.exec(line);
    return m ? { phase: m[1], who: m[2], text: m[3] } : null;
}

function wilson(k, n, z = 1.96) {
    if (!n) return { k, n, rate: null, ci95: null, moe: null };
    const p = k / n, d = 1 + z * z / n;
    const c = (p + z * z / (2 * n)) / d;
    const h = (z * Math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))) / d;
    return { k, n, rate: +p.toFixed(4), ci95: [+(c - h).toFixed(4), +(c + h).toFixed(4)], moe_halfwidth: +h.toFixed(4) };
}

// Seeded PRNG (mulberry32) for the conversation-level bootstrap.
function rng(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
function clusterBootstrap(perConvo, reps = 10000, seed = 20261115) {
    // perConvo: [{k, n}] ; resample conversations with replacement
    const r = rng(seed), stats = [];
    for (let b = 0; b < reps; b++) {
        let K = 0, N = 0;
        for (let i = 0; i < perConvo.length; i++) { const c = perConvo[Math.floor(r() * perConvo.length)]; K += c.k; N += c.n; }
        if (N) stats.push(K / N);
    }
    stats.sort((a, b) => a - b);
    return [+stats[Math.floor(0.025 * stats.length)].toFixed(4), +stats[Math.floor(0.975 * stats.length) - 1].toFixed(4)];
}

const perConvoClosing = [], perConvoAll = [];
let convosWithPrematureAffirm = 0;
const examples = [];

for (const r of ok) {
    let priceTouched = false;
    let kC = 0, nC = 0, kA = 0, nA = 0, premature = false;
    for (const line of r.transcript) {
        const m = parse(line);
        if (!m) continue;
        if (m.who === 'TENANT') {
            const bad = !priceTouched && DAY.test(m.text) && AFFIRM.test(m.text);
            nA++; if (bad) kA++;
            if (m.phase === 'CLOSING') { nC++; if (bad) kC++; }
            if (bad) { premature = true; if (examples.length < 5) examples.push({ iter: r.iter, phase: m.phase, text: m.text }); }
            if (AI_PRICE.test(m.text)) priceTouched = true;
        } else if (landlordPrice(m.text)) {
            priceTouched = true;
        }
    }
    perConvoClosing.push({ k: kC, n: nC });
    perConvoAll.push({ k: kA, n: kA + (nA - kA) });
    if (premature) convosWithPrematureAffirm++;
}

const n = ok.length;
const has = (r, issue) => (r.analysis?.issues || []).includes(issue);
const closed = ok.filter(r => r.analysis?.deal_closed);
const closedWithPrice = closed.filter(r => r.analysis?.agreed_price);
const budgetApplies = closedWithPrice.filter(r => r.listing.price > 2500); // harness sets monthly_budget only when price > 2500

const sum = (arr, key) => arr.reduce((s, c) => s + c[key], 0);
const issueCounts = {};
for (const r of ok) for (const i of r.analysis.issues) issueCounts[i] = (issueCounts[i] || 0) + 1;

const out = {
    source_file: file,
    conversations_total: results.length,
    conversations_succeeded: n,
    conversations_errored: results.length - n,
    errors: results.filter(r => r.error).map(r => ({ iter: r.iter, error: r.error })),
    per_conversation: {
        deal_rate: wilson(closed.length, n),
        // Stricter: closed AND an agreed price was pinned AND no closed_without_acceptance issue.
        deal_rate_strict_agreed_price: wilson(closed.filter(r => r.analysis.agreed_price && !has(r, 'closed_without_acceptance')).length, n),
        closed_without_price_discussion__rubric: wilson(ok.filter(r => has(r, 'closed_without_price_discussion')).length, n),
        any_tenant_reply_affirmed_meeting_before_price__transcript: wilson(convosWithPrematureAffirm, n),
        deals_too_high__agreed_significantly_above_target__of_closed_deals_with_price: wilson(closedWithPrice.filter(r => has(r, 'agreed_significantly_above_target')).length, closedWithPrice.length),
        deals_above_budget__of_closed_deals_where_budget_set: wilson(budgetApplies.filter(r => has(r, 'agreed_above_budget')).length, budgetApplies.length),
        accepted_day_outside_availability: wilson(issueCounts.accepted_day_outside_availability || 0, n),
        tenant_repeated_self: wilson(issueCounts.tenant_repeated_self || 0, n),
        hit_max_turns: wilson(ok.filter(r => r.analysis.too_long).length, n)
    },
    per_reply: {
        closing_phase_replies_affirming_meeting_without_price: Object.assign(
            wilson(sum(perConvoClosing, 'k'), sum(perConvoClosing, 'n')),
            { cluster_bootstrap_ci95: sum(perConvoClosing, 'n') ? clusterBootstrap(perConvoClosing) : null,
              conversations_with_any_closing_reply: perConvoClosing.filter(c => c.n > 0).length }),
        all_tenant_replies_affirming_meeting_without_price: Object.assign(
            wilson(sum(perConvoAll, 'k'), sum(perConvoAll, 'n')),
            { cluster_bootstrap_ci95: clusterBootstrap(perConvoAll) })
    },
    issue_counts: issueCounts,
    harness_aggregate: aggregate,
    avg_agreed_vs_listing: closedWithPrice.length ? +(closedWithPrice.reduce((s, r) => s + r.analysis.agreed_price / r.listing.price, 0) / closedWithPrice.length).toFixed(4) : null,
    examples_premature_affirm: examples
};
console.log(JSON.stringify(out, null, 2));
