#!/usr/bin/env node
/**
 * negotiation_battle.js — end-to-end harness that pits the live AI Negotiator
 * against a Railway-hosted landlord-simulator for N simulated conversations,
 * then scores each one against a rubric.
 *
 * Usage:
 *   SITE=https://www.roomfinderai.com \
 *   SUPABASE_URL=https://<ref>.supabase.co \
 *   SUPABASE_ANON=<anon key> \
 *   node scripts/negotiation_battle.js --iterations 10 --concurrency 5
 *
 * Output:
 *   - Stdout: live per-conversation log + aggregate summary at the end.
 *   - File:   scripts/_results/battle-<iso>.json with the full transcripts +
 *             per-convo analysis.
 *
 * No secrets in code — everything comes from env vars supplied at runtime.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const SITE = process.env.SITE || 'https://www.roomfinderai.com';
const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_ANON = process.env.SUPABASE_ANON || '';

const args = parseArgs(process.argv.slice(2));
const ITERATIONS = Math.max(1, Number(args.iterations || 1));
// Default to fully sequential (one convo at a time). Production has a 100/hr
// rate limit per origin, so parallelism doesn't actually let us do more
// work — it just fails faster with 429s. Override with --concurrency N
// only if you're confident you're under the hourly cap.
const CONCURRENCY = Math.max(1, Number(args.concurrency || 1));
const MAX_TURNS = Math.max(4, Number(args.maxTurns || 18));

// Tenant goal "templates" — the harness rotates through these so we test
// the negotiator under varied conditions (Mon-only / pet-friendly / etc).
const GOAL_TEMPLATES = [
    {
        name: 'mon-only-firm',
        available_days: ['mon'],
        available_time: ['morning'],
        meeting_format: ['in_person'],
        target_reduction: 200,
        ask_utilities_included: true,
        must_haves: ['parking', 'in_unit_laundry'],
        pets: 'dog',
        non_smoker: true,
        employment: 'employed',
        income_confidence: 'strong',
        tone: 'firm',
        assertiveness: 'high'
    },
    {
        name: 'weekend-friendly',
        available_days: ['sat', 'sun'],
        available_time: ['afternoon'],
        meeting_format: ['in_person', 'video'],
        target_reduction: 100,
        must_haves: [],
        pets: 'none',
        employment: 'student',
        income_confidence: 'building',
        tone: 'friendly',
        assertiveness: 'low'
    },
    {
        name: 'professional-medium',
        available_days: ['tue', 'wed', 'thu'],
        available_time: ['evening'],
        meeting_format: ['in_person'],
        target_reduction: 150,
        ask_lower_deposit: true,
        must_haves: ['in_unit_laundry'],
        employment: 'self_employed',
        income_confidence: 'strong',
        tone: 'professional',
        assertiveness: 'medium'
    }
];

const PERSONAS = ['firm', 'flexible', 'chatty', 'realistic'];

async function main() {
    if (!SUPABASE_URL || !SUPABASE_ANON) {
        console.error('Missing SUPABASE_URL or SUPABASE_ANON env. Aborting.');
        process.exit(1);
    }
    console.log(`⚔️  negotiation_battle: ${ITERATIONS} iterations, concurrency=${CONCURRENCY}, maxTurns=${MAX_TURNS}`);
    const listings = await fetchListings();
    console.log(`📋 fetched ${listings.length} listings`);
    if (listings.length === 0) {
        console.error('No listings available; aborting.');
        process.exit(1);
    }

    const startedAt = new Date();
    const results = [];
    let idx = 0;
    const workers = Array.from({ length: CONCURRENCY }, async (_, workerId) => {
        while (true) {
            const myIdx = idx++;
            if (myIdx >= ITERATIONS) break;
            const listing = listings[myIdx % listings.length];
            const goals = GOAL_TEMPLATES[myIdx % GOAL_TEMPLATES.length];
            const persona = PERSONAS[myIdx % PERSONAS.length];
            try {
                const res = await runConversation({ iter: myIdx + 1, listing, goals, persona });
                results.push(res);
                logIterSummary(res);
            } catch (e) {
                results.push({ iter: myIdx + 1, error: String(e?.message || e) });
                console.error(`❌ iter ${myIdx + 1} failed: ${e?.message || e}`);
            }
        }
    });
    await Promise.all(workers);
    const endedAt = new Date();

    const aggregate = summarize(results);
    aggregate.startedAt = startedAt.toISOString();
    aggregate.endedAt = endedAt.toISOString();
    aggregate.wallTimeSec = Math.round((endedAt - startedAt) / 1000);
    aggregate.iterations = ITERATIONS;
    aggregate.concurrency = CONCURRENCY;

    const outDir = path.join(__dirname, '_results');
    fs.mkdirSync(outDir, { recursive: true });
    const outPath = path.join(outDir, `battle-${endedAt.toISOString().replace(/[:.]/g, '-')}.json`);
    fs.writeFileSync(outPath, JSON.stringify({ aggregate, results }, null, 2));
    console.log(`💾 wrote ${outPath}`);
    console.log('');
    console.log('=== AGGREGATE ===');
    console.log(JSON.stringify(aggregate, null, 2));
}

async function fetchListings() {
    const url = `${SUPABASE_URL}/rest/v1/listings?select=id,title,city,price,house_type,bedrooms,user_email,description&limit=20`;
    const res = await fetch(url, {
        headers: { apikey: SUPABASE_ANON, Authorization: `Bearer ${SUPABASE_ANON}` }
    });
    if (!res.ok) throw new Error(`Supabase listings fetch failed: ${res.status}`);
    const all = await res.json();
    // Drop obviously-broken or own-self test listings
    return all.filter(l => l.price && l.title && l.user_email);
}

// One full simulated conversation.
async function runConversation({ iter, listing, goals, persona }) {
    const startMs = Date.now();
    const tenantBudget = Math.max(1, Math.round((listing.price || 1500) * 0.85));
    const messageHistory = [];   // shared transcript [{sender,content,phase}]
    const facts = {
        listing_held_months: null, deposit_amount: null, proposed_meet_date: null,
        has_laundry: null, has_parking: null, pets_allowed: null,
        landlord_said_yes_to_meet: false, landlord_offered_closing: false,
        landlord_last_named_price: null, agreed_price: null
    };
    let phase = 'INTRODUCTION';
    let tone = 'NEUTRAL';
    let alreadyAsked = [];
    let alreadySharedCredentials = false;
    let currentOffer = null;
    let landlordCounterOffer = null;
    const tenantGoals = Object.assign({}, goals, { monthly_budget: listing.price > 2500 ? Math.round(listing.price * 1.1) : 0 });
    // Middle-ground closing detection: catches real closing language
    // (let's meet Monday, see you Saturday/this weekend, sign the lease,
    // deal at $X) but does NOT catch generic affirmations ("works for me"
    // answering "is parking ok?"). Iter 7 went too tight; iter 8 walks it
    // back; iter 9 adds "this weekend" / "next week" / "then" — common
    // closing in the harness convos that the day-only regex missed.
    const closingRe = /\b(deal\b|sold\b|i.?ll take it|we.?ll take it|let.?s do (it|that)|sign the lease|put down the deposit|see you (this weekend|next week|then|tomorrow|mon|tues|wed|thur|fri|sat|sun)|let.?s meet (this weekend|next week|mon|tues|wed|thur|fri|sat|sun|on)|let.?s sign|done deal|come (sign|by saturday|by sunday|by monday|by tuesday|by wednesday|by thursday|by friday))\b/i;
    let closingTurnsSeen = 0;       // increments every loop while phase === 'CLOSING'
    const issues = [];

    // Turn loop. Always start with a tenant (AI Negotiator) message.
    for (let turn = 1; turn <= MAX_TURNS; turn++) {
        // ---------- TENANT TURN ----------
        const ctx = {
            userName: 'Alex',
            propertyTitle: listing.title || 'your place',
            propertyFeature: featureFromDescription(listing.description),
            city: listing.city || 'the area',
            userBudget: tenantBudget,
            listingPrice: listing.price,
            lastLandlordMessage: lastMessageOfSender(messageHistory, 'landlord') || '',
            currentOffer,
            landlordCounterOffer,
            agreedPrice: facts.agreed_price
        };
        const tenantResp = await postJSON(`${SITE}/api/negotiate/phase-message`, {
            phase, tone, facts, alreadyAsked,
            alreadySharedCredentials, tenantGoals, context: ctx,
            messageHistory: messageHistory.map(m => ({ sender: m.sender, content: m.content }))
        });
        const tenantMsg = String(tenantResp?.response || '').trim();
        if (!tenantMsg) { issues.push('empty_tenant_response'); break; }
        messageHistory.push({ sender: 'ai', content: tenantMsg, phase });

        // Extract any $ amount the tenant just offered.
        const t$ = findFirstPrice(tenantMsg, { min: 100, max: 50000 });
        if (t$ != null) currentOffer = t$;

        // Phase-locked credential pitch sticks once any QUALIFICATION turn happened.
        if (phase === 'QUALIFICATION') alreadySharedCredentials = true;

        // Did the tenant just signal closing? Lock phase to CLOSING.
        if (closingRe.test(tenantMsg) && phase !== 'CLOSING') {
            phase = 'CLOSING';
        }

        // ---------- LANDLORD TURN ----------
        // Termination logic: a conversation is REALLY closed only when the
        // tenant's most recent message is an actual ACCEPT — not a counter or
        // a probe. Earlier version terminated on any CLOSING-phase entry with
        // a named price, which made the harness wrongly label perfectly good
        // counter-offers as "deals closed at landlord's price." If the tenant
        // is still actively negotiating (asking "is X firm?", proposing a
        // counter "$X is more my range"), keep looping.
        // Tightened: a tenant ACCEPTING needs strong commit language, not
        // generic affirmations that may be answering a property question
        // ("yes parking works for me" ≠ "accepting the deal"). Also catches
        // "see you this weekend" / "see you then" — common closing phrasings
        // the day-name-only regex missed.
        const tenantIsAccepting = /\b(deal\b|done deal|i.?ll take it|let.?s do (it|that)|let.?s sign|happy to (sign|move forward)|see you (this weekend|next week|then|tomorrow|mon|tues|wed|thur|fri|sat|sun))\b/i.test(tenantMsg);
        const tenantIsCountering = /\b(could (we|you)|how about|what (about|if)|more in my range|stretch to|meet (in )?(the )?middle|firm|wiggle|flexibility|any room|is the .* firm)\b/i.test(tenantMsg) || /\?/.test(tenantMsg);
        if (phase === 'CLOSING') {
            closingTurnsSeen++;
            if (tenantIsAccepting && !tenantIsCountering) {
                // Real close: pin agreed price from the last named price.
                if (!facts.agreed_price) {
                    facts.agreed_price = facts.landlord_last_named_price || currentOffer || null;
                }
                break;
            }
            if (closingTurnsSeen >= 3 && tenantIsAccepting) {
                // Allow one extra back-and-forth in CLOSING if tenant is mid-counter, then terminate.
                if (!facts.agreed_price) {
                    facts.agreed_price = currentOffer || facts.landlord_last_named_price || null;
                }
                break;
            }
            if (closingTurnsSeen >= 4) {
                // Hard stop after 4 CLOSING turns to prevent infinite loops.
                // Only flag as "closed without acceptance" if no price has
                // converged — if numeric convergence already pinned an
                // agreed_price, the deal effectively did close (the bots
                // just didn't say "I'll take it" explicitly).
                if (!facts.agreed_price) {
                    issues.push('closed_without_acceptance');
                }
                break;
            }
        }
        const landlordResp = await postJSON(`${SITE}/api/landlord-simulator`, {
            messageHistory: messageHistory.map(m => ({ sender: m.sender, content: m.content })),
            listing,
            persona
        });
        const landlordMsg = String(landlordResp?.reply || '').trim();
        if (!landlordMsg) { issues.push('empty_landlord_response'); break; }
        messageHistory.push({ sender: 'landlord', content: landlordMsg, phase });

        // Extract landlord-side facts.
        const l$ = findFirstPrice(landlordMsg, { min: 100, max: 50000 });
        if (l$ != null) {
            facts.landlord_last_named_price = l$;
            landlordCounterOffer = l$;
        }
        if (/\b(meet|see you|come by|stop by|swing by|tomorrow|today|tonight|monday|tuesday|wednesday|thursday|friday|saturday|sunday|this weekend)\b/i.test(landlordMsg)) {
            facts.landlord_offered_closing = true;
            const dayMatch = landlordMsg.toLowerCase().match(/\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|tonight|today)\b/);
            if (dayMatch && !facts.proposed_meet_date) facts.proposed_meet_date = dayMatch[1];
        }
        if (closingRe.test(landlordMsg)) {
            // Landlord signaled closing.
            phase = 'CLOSING';
        }

        // Numeric convergence => deal closed.
        if (currentOffer && facts.landlord_last_named_price && Math.abs(currentOffer - facts.landlord_last_named_price) <= 25) {
            facts.agreed_price = Math.round((currentOffer + facts.landlord_last_named_price) / 2);
            phase = 'CLOSING';
        }

        // Phase advance (light heuristic — mirrors the frontend's regexes).
        phase = advancePhase(phase, landlordMsg, messageHistory, facts);
    }

    const endMs = Date.now();
    const analysis = analyze({ messageHistory, facts, phase, tenantGoals, listing, currentOffer, issues });
    return {
        iter,
        listing: { id: listing.id, title: listing.title, city: listing.city, price: listing.price, owner: listing.user_email },
        goals_template: goals.name,
        landlord_persona: persona,
        turns: messageHistory.length,
        terminal_phase: phase,
        analysis,
        elapsed_ms: endMs - startMs,
        transcript: messageHistory.map(m => `[${m.phase}] ${m.sender === 'ai' ? 'TENANT' : 'LANDLORD'}: ${m.content}`)
    };
}

function analyze({ messageHistory, facts, phase, tenantGoals, listing, currentOffer, issues }) {
    const out = {
        deal_closed: phase === 'CLOSING' && !!(facts.agreed_price || facts.landlord_offered_closing),
        agreed_price: facts.agreed_price,
        landlord_last_named_price: facts.landlord_last_named_price,
        tenant_last_offer: currentOffer,
        turns_to_close: phase === 'CLOSING' ? messageHistory.length : null,
        too_long: messageHistory.length >= MAX_TURNS,
        issues: issues.slice()
    };
    // Quality checks against tenant goals.
    if (Array.isArray(tenantGoals.available_days) && tenantGoals.available_days.length && facts.proposed_meet_date) {
        const allowed = tenantGoals.available_days.map(d => ({mon:'monday',tue:'tuesday',wed:'wednesday',thu:'thursday',fri:'friday',sat:'saturday',sun:'sunday'}[d]||d));
        if (!allowed.includes(String(facts.proposed_meet_date).toLowerCase())) {
            // Did the AI accept it or counter it?
            const tail = messageHistory.slice(-4).map(m => m.content).join(' ').toLowerCase();
            const aiAffirmed = /\b(works|sounds good|see you|let.?s meet)\b/i.test(tail) && !/\binstead\b|\bcould we (?:do|meet)\b/i.test(tail);
            if (aiAffirmed) out.issues.push('accepted_day_outside_availability');
        }
    }
    // Premature meet (CLOSING reached without a price ever discussed).
    if (phase === 'CLOSING' && !facts.landlord_last_named_price && !currentOffer) {
        out.issues.push('closed_without_price_discussion');
    }
    // Price overshoot (AI accepted price above tenant's target ceiling).
    if (facts.agreed_price && tenantGoals.monthly_budget && facts.agreed_price > tenantGoals.monthly_budget) {
        out.issues.push('agreed_above_budget');
    }
    if (facts.agreed_price && tenantGoals.target_reduction) {
        const targetRent = Math.max(0, listing.price - tenantGoals.target_reduction);
        if (facts.agreed_price > targetRent + 75) out.issues.push('agreed_significantly_above_target');
    }
    // Tenant message repetition (asked same question twice — bad).
    const tenantMsgs = messageHistory.filter(m => m.sender === 'ai').map(m => m.content.toLowerCase());
    for (let i = 1; i < tenantMsgs.length; i++) {
        for (let j = 0; j < i; j++) {
            const a = tenantMsgs[i], b = tenantMsgs[j];
            if (a.length > 20 && b.length > 20 && (a.includes(b.slice(0, 30)) || b.includes(a.slice(0, 30)))) {
                out.issues.push('tenant_repeated_self');
                i = tenantMsgs.length; break;
            }
        }
    }
    // Score: 1.0 = perfect. Subtract for issues.
    const penalties = { accepted_day_outside_availability: 0.4, closed_without_price_discussion: 0.4, agreed_above_budget: 0.5, agreed_significantly_above_target: 0.2, tenant_repeated_self: 0.15 };
    let score = 1.0;
    for (const i of out.issues) score -= (penalties[i] || 0.1);
    if (!out.deal_closed) score -= 0.25;
    if (out.too_long) score -= 0.15;
    out.score = Math.max(0, Number(score.toFixed(2)));
    return out;
}

function summarize(results) {
    const ok = results.filter(r => !r.error);
    const closed = ok.filter(r => r.analysis?.deal_closed);
    const avgTurns = ok.length ? Math.round(ok.reduce((s, r) => s + r.turns, 0) / ok.length) : 0;
    const avgScore = ok.length ? Number((ok.reduce((s, r) => s + (r.analysis?.score || 0), 0) / ok.length).toFixed(2)) : 0;
    const avgAgreedPrice = closed.filter(r => r.analysis?.agreed_price).length
        ? Math.round(closed.filter(r => r.analysis?.agreed_price).reduce((s, r) => s + r.analysis.agreed_price, 0) / closed.filter(r => r.analysis?.agreed_price).length)
        : null;
    const issueCounts = {};
    for (const r of ok) for (const i of (r.analysis?.issues || [])) issueCounts[i] = (issueCounts[i] || 0) + 1;
    return {
        total: results.length,
        succeeded: ok.length,
        errored: results.length - ok.length,
        deals_closed: closed.length,
        close_rate: ok.length ? Number((closed.length / ok.length).toFixed(2)) : 0,
        avg_turns: avgTurns,
        avg_score: avgScore,
        avg_agreed_price: avgAgreedPrice,
        top_issues: Object.entries(issueCounts).sort((a, b) => b[1] - a[1])
    };
}

function logIterSummary(r) {
    if (r.error) return;
    const a = r.analysis;
    const closed = a.deal_closed ? '✅' : '❌';
    const agreed = a.agreed_price ? `$${a.agreed_price}` : '—';
    console.log(`  iter ${String(r.iter).padStart(3)} | ${closed} closed | turns=${String(r.turns).padStart(2)} | agreed=${agreed.padStart(6)} | score=${a.score} | issues=[${a.issues.join(',')}] | ${r.goals_template}/${r.landlord_persona} | ${r.listing.title?.slice(0, 30)}`);
}

// ---------- helpers ----------

function parseArgs(argv) {
    const out = {};
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a.startsWith('--')) {
            const key = a.slice(2);
            const val = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : true;
            out[key] = val;
        }
    }
    return out;
}

async function postJSON(url, body) {
    const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
    });
    if (!res.ok) {
        const text = await res.text().catch(() => '');
        throw new Error(`POST ${url} failed ${res.status}: ${text.slice(0, 200)}`);
    }
    return res.json();
}

function findFirstPrice(text, { min = 100, max = 50000 } = {}) {
    const matches = String(text || '').match(/\$?\s*(\d{1,3}(?:[,]\d{3})+|\d{3,5})(?:\.\d{1,2})?/g);
    if (!matches) return null;
    for (const raw of matches) {
        const n = parseFloat(raw.replace(/[$,\s]/g, ''));
        if (n >= min && n <= max) return n;
    }
    return null;
}

function lastMessageOfSender(history, sender) {
    for (let i = history.length - 1; i >= 0; i--) {
        if (history[i].sender === sender) return history[i].content;
    }
    return null;
}

function featureFromDescription(desc) {
    if (!desc) return 'the layout';
    const keywords = ['hardwood', 'granite', 'high ceiling', 'balcony', 'view', 'fireplace', 'stainless'];
    for (const k of keywords) if (new RegExp(k, 'i').test(desc)) return k;
    return 'the layout';
}

function advancePhase(currentPhase, landlordMsg, messageHistory, facts) {
    const order = ['INTRODUCTION','RAPPORT_BUILDING','QUALIFICATION','PRICE_INTRODUCTION','ACTIVE_NEGOTIATION','AVAILABILITY_DISCUSSION','CLOSING'];
    // CLOSING regex from frontend.
    if (/\b(meet|deposit|sign|lease|tomorrow|address|move in|done deal|let.?s do it|i.?ll take it|we.?ll take it|deal|agreed|sold|sounds good|works for me|that works)\b/i.test(landlordMsg)) {
        return 'CLOSING';
    }
    if (/\b(\$\d+|price|rent|budget|cost|afford|monthly|per month|how much|offer|firm|flexible|wiggle|counter)\b/i.test(landlordMsg) && currentPhase !== 'ACTIVE_NEGOTIATION') {
        return currentPhase === 'PRICE_INTRODUCTION' ? 'ACTIVE_NEGOTIATION' : 'PRICE_INTRODUCTION';
    }
    if (/\b(job|work|employ|income|credit|reference|background|tell me about)\b/i.test(landlordMsg) && (currentPhase === 'INTRODUCTION' || currentPhase === 'RAPPORT_BUILDING')) {
        return 'QUALIFICATION';
    }
    // Default: advance one phase per landlord reply, up to ACTIVE.
    const idx = order.indexOf(currentPhase);
    if (idx >= 0 && idx < 4) return order[idx + 1];
    return currentPhase;
}

main().catch(e => {
    console.error('fatal:', e);
    process.exit(1);
});
