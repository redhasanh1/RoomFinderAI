#!/usr/bin/env node
/**
 * negotiation_coach.js — INTERACTIVE variant of negotiation_battle.js.
 *
 * You play the LANDLORD at a terminal prompt; the AI Negotiator plays the
 * TENANT using the real /api/negotiate/phase-message endpoint (point it at a
 * LOCAL backend so prompt changes are testable without deploying). The full
 * conversation is captured, scored against the same rubric as the battle
 * harness, and written to scripts/_results/coach-<iso>.json so it can be
 * analyzed and the prompt logic improved — one conversation at a time.
 *
 * Usage:
 *   # 1) start the backend locally in another terminal:
 *   #    $env:OPENAI_API_KEY="sk-..."; $env:OPENAI_MODEL="gpt-4"; node backend/server.js
 *   # 2) then:
 *   node scripts/negotiation_coach.js
 *   node scripts/negotiation_coach.js --site http://localhost:3000 --goals mon-only-firm --price 2025
 *
 * Commands while chatting:
 *   /done   end the conversation, score it, save the transcript
 *   /score  print the current rubric score without ending
 *   /save   write the transcript so far without ending
 *   /goals <name|list>  switch tenant goal template (mon-only-firm | weekend-friendly | professional-medium)
 *   /state  print the current phase / tone / facts
 *   /help   show commands
 *   /quit   exit without scoring
 *
 * No secrets in code — the OpenAI key lives only in the backend's env.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const args = parseArgs(process.argv.slice(2));
const SITE = String(args.site || process.env.SITE || 'http://localhost:3000').replace(/\/$/, '');
const MAX_TURNS = Math.max(4, Number(args.maxTurns || 40));

// Tenant goal templates — identical to the battle harness so the coach tests
// the negotiator under the same varied conditions.
const GOAL_TEMPLATES = [
    {
        name: 'mon-only-firm',
        available_days: ['mon'], available_time: ['morning'], meeting_format: ['in_person'],
        target_reduction: 200, ask_utilities_included: true,
        must_haves: ['parking', 'in_unit_laundry'], pets: 'dog', non_smoker: true,
        employment: 'employed', income_confidence: 'strong', tone: 'firm', assertiveness: 'high'
    },
    {
        name: 'weekend-friendly',
        available_days: ['sat', 'sun'], available_time: ['afternoon'], meeting_format: ['in_person', 'video'],
        target_reduction: 100, must_haves: [], pets: 'none',
        employment: 'student', income_confidence: 'building', tone: 'friendly', assertiveness: 'low'
    },
    {
        name: 'professional-medium',
        available_days: ['tue', 'wed', 'thu'], available_time: ['evening'], meeting_format: ['in_person'],
        target_reduction: 150, ask_lower_deposit: true, must_haves: ['in_unit_laundry'],
        employment: 'self_employed', income_confidence: 'strong', tone: 'professional', assertiveness: 'medium'
    }
];

// Sample listing — no Supabase needed for the coach. Override via flags.
const listing = {
    id: 'local-sample',
    title: String(args.title || 'Premium 3-Bedroom Apartment'),
    city: String(args.city || 'Toronto'),
    price: Number(args.price || 2025),
    house_type: 'apartment',
    bedrooms: 3,
    user_email: 'landlord@example.com',
    description: 'Spacious unit with hardwood floors, a balcony, and great natural light.'
};

// Closing-signal regex (copied from the battle harness).
const closingRe = /\b(deal\b|sold\b|i.?ll take it|we.?ll take it|let.?s do (it|that)|sign the lease|put down the deposit|see you (this weekend|next week|then|tomorrow|mon|tues|wed|thur|fri|sat|sun)|let.?s meet (this weekend|next week|mon|tues|wed|thur|fri|sat|sun|on)|let.?s sign|done deal|come (sign|by saturday|by sunday|by monday|by tuesday|by wednesday|by thursday|by friday))\b/i;
// Landlord frustration → flips tone to FRUSTRATED (sticky) so the coach can
// exercise the backend's damage-control branch. Not in the battle harness.
const frustratedRe = /\b(stop|annoying|waste|ridiculous|scam|rude|fuck|shit|piss|pissed|angry|forget it|not interested|leave me alone|wasting my time|seriously\?)\b/i;

// ---------- conversation state (mirrors negotiation_battle.js:154-176) ----------
const messageHistory = [];   // [{sender:'ai'|'landlord', content, phase}]
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
let closingTurnsSeen = 0;
const issues = [];

const tenantBudget = Math.max(1, Math.round((listing.price || 1500) * 0.85));
let goals = pickGoals(args.goals);
let tenantGoals = buildTenantGoals(goals);
const startedAt = Date.now();

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

// Event-driven input: buffer landlord lines in a queue and process them one at
// a time (each tenant reply is an async OpenAI call). Driving off 'line'/'close'
// instead of recursive rl.question() means piped/scripted input (EOF) ends the
// session cleanly and scores it, instead of throwing ERR_USE_AFTER_CLOSE.
const inputQueue = [];
let inputClosed = false;
let notifyInput = null;
let finished = false;
rl.on('line', (raw) => { inputQueue.push(String(raw)); if (notifyInput) { const n = notifyInput; notifyInput = null; n(); } });
rl.on('close', () => { inputClosed = true; if (notifyInput) { const n = notifyInput; notifyInput = null; n(); } });
const showPrompt = () => { if (!inputClosed) { try { rl.prompt(true); } catch (_) {} } };

async function run() {
    banner();
    // Always open with a tenant (AI) message, then hand the prompt to you.
    const ok = await tenantTurn();
    if (!ok) {
        console.error('\n⚠️  Could not reach the backend at ' + SITE + '. Is `node backend/server.js` running with OPENAI_API_KEY set?');
        try { rl.close(); } catch (_) {}
        process.exit(1);
    }
    rl.setPrompt('\n🧑‍💼 Landlord > ');
    showPrompt();
    while (true) {
        while (inputQueue.length === 0 && !inputClosed) await new Promise(res => { notifyInput = res; });
        if (inputQueue.length === 0 && inputClosed) break;   // stdin EOF
        const text = inputQueue.shift().trim();
        if (!text) { showPrompt(); continue; }
        const stop = await handleLine(text);
        if (stop === 'quit') { console.log('👋 exited (not scored).'); try { rl.close(); } catch (_) {} process.exit(0); }
        if (stop === 'done') break;
        showPrompt();
    }
    if (!finished) await finish();   // EOF without /done → score anyway
    try { rl.close(); } catch (_) {}
    process.exit(0);
}

// Handle one input line. Returns 'done' (scored+saved), 'quit' (exit, no score), or null (continue).
async function handleLine(text) {
    if (text.startsWith('/')) {
        const [cmd, ...rest] = text.slice(1).split(/\s+/);
        const arg = rest.join(' ').trim();
        if (cmd === 'quit' || cmd === 'q') return 'quit';
        if (cmd === 'done') { await finish(); return 'done'; }
        if (cmd === 'help' || cmd === 'h') { help(); return null; }
        if (cmd === 'state') { printState(); return null; }
        if (cmd === 'score') { console.log(fmtAnalysis(analyze())); return null; }
        if (cmd === 'save') { const p = save(analyze()); console.log('💾 ' + p); return null; }
        if (cmd === 'goals') {
            if (!arg || arg === 'list') { console.log('templates: ' + GOAL_TEMPLATES.map(g => g.name).join(', ') + `  (current: ${goals.name})`); return null; }
            const g = GOAL_TEMPLATES.find(t => t.name === arg);
            if (!g) { console.log('unknown template. options: ' + GOAL_TEMPLATES.map(t => t.name).join(', ')); return null; }
            goals = g; tenantGoals = buildTenantGoals(goals);
            console.log(`🎯 tenant goals → ${goals.name} (days=[${goals.available_days}], target_reduction=$${goals.target_reduction})`);
            return null;
        }
        console.log('unknown command. /help for the list.'); return null;
    }
    landlordTurn(text);
    const ok = await tenantTurn();
    if (!ok) console.error('⚠️ backend call failed — fix the backend and type your message again.');
    if (messageHistory.length >= MAX_TURNS) { console.log(`\n⏱️  hit maxTurns=${MAX_TURNS}. Wrapping up.`); await finish(); return 'done'; }
    return null;
}

// Generate + print the AI tenant's reply for the current state.
// Mirrors the TENANT TURN block in negotiation_battle.js:180-242.
async function tenantTurn() {
    const ctx = {
        userName: 'Alex',
        propertyTitle: listing.title || 'your place',
        propertyFeature: featureFromDescription(listing.description),
        city: listing.city || 'the area',
        userBudget: tenantBudget,
        listingPrice: listing.price,
        lastLandlordMessage: lastMessageOfSender(messageHistory, 'landlord') || '',
        currentOffer, landlordCounterOffer, agreedPrice: facts.agreed_price
    };
    let resp;
    try {
        resp = await postJSON(`${SITE}/api/negotiate/phase-message`, {
            phase, tone, facts, alreadyAsked, alreadySharedCredentials, tenantGoals,
            context: ctx,
            messageHistory: messageHistory.map(m => ({ sender: m.sender, content: m.content }))
        });
    } catch (e) {
        console.error('  ↳ ' + (e && e.message ? e.message : e));
        return false;
    }
    const tenantMsg = String(resp?.response || '').trim();
    if (!tenantMsg) { console.error('  ↳ empty tenant response'); return false; }

    messageHistory.push({ sender: 'ai', content: tenantMsg, phase });

    // Offer extraction — only treat $ as a commitment, not a reference to the
    // landlord's number in a probe (battle harness:219-234).
    const t$ = findFirstPrice(tenantMsg, { min: 100, max: 50000 });
    if (t$ != null) {
        const isCommitment = /\b(could (we|you) do|how about|i can (do|stretch|commit)|what about|propose|land at|more in my range|meet (in )?(the )?middle|i.?m at|my (budget|range|target|comfortable) (is|around))\b/i.test(tenantMsg);
        const isReference = /\b(is (the|this|that)? ?\$?[\d,]+ firm|any (room|wiggle|flexibility)|firm at|wiggle room)\b/i.test(tenantMsg);
        if (isCommitment && !isReference && t$ !== facts.landlord_last_named_price) currentOffer = t$;
    }
    if (phase === 'QUALIFICATION') alreadySharedCredentials = true;
    if (closingRe.test(tenantMsg) && phase !== 'CLOSING') phase = 'CLOSING';
    if (phase === 'CLOSING') closingTurnsSeen++;

    console.log(`\n🤖 TENANT [${phase}/${tone}]: ${tenantMsg}`);
    return true;
}

// Process a typed landlord message — mirrors the LANDLORD TURN fact-extraction
// in negotiation_battle.js:294-319 (minus the simulator call).
function landlordTurn(text) {
    messageHistory.push({ sender: 'landlord', content: text, phase });

    const l$ = findFirstPrice(text, { min: 100, max: 50000 });
    if (l$ != null) { facts.landlord_last_named_price = l$; landlordCounterOffer = l$; }

    if (/\b(meet|see you|come by|stop by|swing by|tomorrow|today|tonight|monday|tuesday|wednesday|thursday|friday|saturday|sunday|this weekend)\b/i.test(text)) {
        facts.landlord_offered_closing = true;
        const dayMatch = text.toLowerCase().match(/\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|tonight|today)\b/);
        if (dayMatch && !facts.proposed_meet_date) facts.proposed_meet_date = dayMatch[1];
    }
    if (frustratedRe.test(text)) tone = 'FRUSTRATED';            // sticky
    else if (closingRe.test(text) && tone !== 'FRUSTRATED') tone = 'ENGAGED';
    if (closingRe.test(text)) phase = 'CLOSING';

    // Numeric convergence => deal closed.
    if (currentOffer && facts.landlord_last_named_price && Math.abs(currentOffer - facts.landlord_last_named_price) <= 25) {
        facts.agreed_price = Math.round((currentOffer + facts.landlord_last_named_price) / 2);
        phase = 'CLOSING';
    }
    phase = advancePhase(phase, text, messageHistory, facts);
}

async function finish() {
    if (finished) return;
    finished = true;
    if (!facts.agreed_price && phase === 'CLOSING') facts.agreed_price = facts.landlord_last_named_price || currentOffer || null;
    const a = analyze();
    const p = save(a);
    console.log('\n=== CONVERSATION SCORED ===');
    console.log(fmtAnalysis(a));
    console.log('💾 transcript: ' + p);
    console.log('   (paste that path to me and I\'ll analyze it + improve the prompt logic.)');
}

// ---------- rubric (verbatim from negotiation_battle.js:337-388) ----------
function analyze() {
    const out = {
        deal_closed: phase === 'CLOSING' && !!(facts.agreed_price || facts.landlord_offered_closing),
        agreed_price: facts.agreed_price,
        landlord_last_named_price: facts.landlord_last_named_price,
        tenant_last_offer: currentOffer,
        turns_to_close: phase === 'CLOSING' ? messageHistory.length : null,
        too_long: messageHistory.length >= MAX_TURNS,
        issues: issues.slice()
    };
    if (Array.isArray(tenantGoals.available_days) && tenantGoals.available_days.length && facts.proposed_meet_date) {
        const allowed = tenantGoals.available_days.map(d => ({ mon: 'monday', tue: 'tuesday', wed: 'wednesday', thu: 'thursday', fri: 'friday', sat: 'saturday', sun: 'sunday' }[d] || d));
        if (!allowed.includes(String(facts.proposed_meet_date).toLowerCase())) {
            const tail = messageHistory.slice(-4).map(m => m.content).join(' ').toLowerCase();
            const aiAffirmed = /\b(works|sounds good|see you|let.?s meet)\b/i.test(tail) && !/\binstead\b|\bcould we (?:do|meet)\b/i.test(tail);
            if (aiAffirmed) out.issues.push('accepted_day_outside_availability');
        }
    }
    if (phase === 'CLOSING' && !facts.landlord_last_named_price && !currentOffer) out.issues.push('closed_without_price_discussion');
    if (facts.agreed_price && tenantGoals.monthly_budget && facts.agreed_price > tenantGoals.monthly_budget) out.issues.push('agreed_above_budget');
    if (facts.agreed_price && tenantGoals.target_reduction) {
        const targetRent = Math.max(0, listing.price - tenantGoals.target_reduction);
        if (facts.agreed_price > targetRent + 75) out.issues.push('agreed_significantly_above_target');
    }
    const tenantMsgs = messageHistory.filter(m => m.sender === 'ai').map(m => m.content.toLowerCase());
    for (let i = 1; i < tenantMsgs.length; i++) {
        for (let j = 0; j < i; j++) {
            const a = tenantMsgs[i], b = tenantMsgs[j];
            if (a.length > 20 && b.length > 20 && (a.includes(b.slice(0, 30)) || b.includes(a.slice(0, 30)))) {
                out.issues.push('tenant_repeated_self'); i = tenantMsgs.length; break;
            }
        }
    }
    const penalties = { accepted_day_outside_availability: 0.4, closed_without_price_discussion: 0.4, agreed_above_budget: 0.5, agreed_significantly_above_target: 0.2, tenant_repeated_self: 0.15 };
    let score = 1.0;
    for (const i of out.issues) score -= (penalties[i] || 0.1);
    if (!out.deal_closed) score -= 0.25;
    if (out.too_long) score -= 0.15;
    out.score = Math.max(0, Number(score.toFixed(2)));
    return out;
}

function save(analysis) {
    const outDir = path.join(__dirname, '_results');
    fs.mkdirSync(outDir, { recursive: true });
    const outPath = path.join(outDir, `coach-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
    fs.writeFileSync(outPath, JSON.stringify({
        site: SITE,
        listing: { id: listing.id, title: listing.title, city: listing.city, price: listing.price },
        tenantGoals, goals_template: goals.name,
        terminal_phase: phase, tone,
        finalState: { facts, currentOffer, landlordCounterOffer, alreadyAsked, alreadySharedCredentials },
        analysis,
        elapsed_ms: Date.now() - startedAt,
        transcript: messageHistory.map(m => `[${m.phase}] ${m.sender === 'ai' ? 'TENANT' : 'LANDLORD'}: ${m.content}`)
    }, null, 2));
    return outPath;
}

// ---------- helpers (copied from negotiation_battle.js) ----------
function parseArgs(argv) {
    const out = {};
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a.startsWith('--')) { const key = a.slice(2); const val = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : true; out[key] = val; }
    }
    return out;
}
async function postJSON(url, body) {
    const res = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    if (!res.ok) { const text = await res.text().catch(() => ''); throw new Error(`POST ${url} failed ${res.status}: ${text.slice(0, 200)}`); }
    return res.json();
}
function findFirstPrice(text, { min = 100, max = 50000 } = {}) {
    const matches = String(text || '').match(/\$?\s*(\d{1,3}(?:[,]\d{3})+|\d{3,5})(?:\.\d{1,2})?/g);
    if (!matches) return null;
    for (const raw of matches) { const n = parseFloat(raw.replace(/[$,\s]/g, '')); if (n >= min && n <= max) return n; }
    return null;
}
function lastMessageOfSender(history, sender) {
    for (let i = history.length - 1; i >= 0; i--) if (history[i].sender === sender) return history[i].content;
    return null;
}
function featureFromDescription(desc) {
    if (!desc) return 'the layout';
    for (const k of ['hardwood', 'granite', 'high ceiling', 'balcony', 'view', 'fireplace', 'stainless']) if (new RegExp(k, 'i').test(desc)) return k;
    return 'the layout';
}
function advancePhase(currentPhase, landlordMsg, messageHistory, facts) {
    const order = ['INTRODUCTION', 'RAPPORT_BUILDING', 'QUALIFICATION', 'PRICE_INTRODUCTION', 'ACTIVE_NEGOTIATION', 'AVAILABILITY_DISCUSSION', 'CLOSING'];
    if (/\b(meet|deposit|sign|lease|tomorrow|address|move in|done deal|let.?s do it|i.?ll take it|we.?ll take it|deal|agreed|sold|sounds good|works for me|that works)\b/i.test(landlordMsg)) return 'CLOSING';
    if (/\b(\$\d+|price|rent|budget|cost|afford|monthly|per month|how much|offer|firm|flexible|wiggle|counter)\b/i.test(landlordMsg) && currentPhase !== 'ACTIVE_NEGOTIATION') return currentPhase === 'PRICE_INTRODUCTION' ? 'ACTIVE_NEGOTIATION' : 'PRICE_INTRODUCTION';
    if (/\b(job|work|employ|income|credit|reference|background|tell me about)\b/i.test(landlordMsg) && (currentPhase === 'INTRODUCTION' || currentPhase === 'RAPPORT_BUILDING')) return 'QUALIFICATION';
    const idx = order.indexOf(currentPhase);
    if (idx >= 0 && idx < 4) return order[idx + 1];
    return currentPhase;
}

// ---------- presentation ----------
function pickGoals(name) {
    if (name && name !== true) { const g = GOAL_TEMPLATES.find(t => t.name === name); if (g) return g; console.log(`unknown --goals "${name}", using ${GOAL_TEMPLATES[0].name}`); }
    return GOAL_TEMPLATES[0];
}
function buildTenantGoals(g) {
    return Object.assign({}, g, { monthly_budget: listing.price > 2500 ? Math.round(listing.price * 1.1) : 0 });
}
function banner() {
    const targetRent = Math.max(0, listing.price - (goals.target_reduction || 0));
    console.log('══════════════════════════════════════════════════════════════');
    console.log('  AI NEGOTIATION COACH — you are the LANDLORD, AI is the TENANT');
    console.log('══════════════════════════════════════════════════════════════');
    console.log(`  backend:  ${SITE}`);
    console.log(`  listing:  ${listing.title} — ${listing.city} — $${listing.price}/mo`);
    console.log(`  tenant:   goals=${goals.name}  budget≈$${tenantBudget}  target≈$${targetRent}  days=[${goals.available_days}]`);
    console.log('  commands: /done  /score  /save  /goals <name>  /state  /help  /quit');
    console.log('══════════════════════════════════════════════════════════════');
}
function help() {
    console.log([
        '  /done           end + score + save the transcript',
        '  /score          show the current rubric score',
        '  /save           write the transcript so far',
        '  /goals <name>   switch tenant goals (or "/goals list")',
        '  /state          show phase / tone / facts',
        '  /quit           exit without scoring'
    ].join('\n'));
}
function printState() {
    console.log(`  phase=${phase} tone=${tone} currentOffer=${currentOffer} landlordPrice=${facts.landlord_last_named_price} agreed=${facts.agreed_price} meetDay=${facts.proposed_meet_date}`);
}
function fmtAnalysis(a) {
    return [
        `  score:        ${a.score}`,
        `  deal_closed:  ${a.deal_closed}`,
        `  agreed_price: ${a.agreed_price ?? '—'}   (tenant_last_offer=${a.tenant_last_offer ?? '—'}, landlord_named=${a.landlord_last_named_price ?? '—'})`,
        `  turns:        ${messageHistory.length}${a.too_long ? ' (too_long)' : ''}`,
        `  issues:       ${a.issues.length ? a.issues.join(', ') : 'none'}`
    ].join('\n');
}

run().catch(e => { console.error('fatal:', e); try { rl.close(); } catch (_) {} process.exit(1); });
