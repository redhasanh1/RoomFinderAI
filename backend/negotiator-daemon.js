/**
 * Answers landlords while the app is closed.
 *
 * The negotiation loop lived entirely on the phone: the app polled the thread,
 * called /api/negotiate/reply and posted the answer. So the AI only argued for
 * you while you were watching it, which is the opposite of the promise — people
 * start a negotiation, lock their phone, and the landlord's reply sits there
 * unanswered until the app is opened again. Testers read that as "the AI is
 * really slow"; it had actually stopped.
 *
 * This runs on the server instead. Every tick it looks for AI-run conversations
 * whose last word came from the landlord, and answers them.
 */

// Six seconds, not twenty. A landlord typing in real time watches the reply
// take long enough that the negotiation reads as broken, and the tick is a
// cheap query against a short list of conversations — the model call only
// happens when there is actually something to answer.
const { sendToUser } = require('./push');

const TICK_MS = Number(process.env.NEGOTIATOR_TICK_MS) || 6000;
/// A negotiation that has gone this many rounds is not converging, and every
/// round costs a model call. Someone can always take it over by hand.
const MAX_AI_MESSAGES = Number(process.env.NEGOTIATOR_MAX_MESSAGES) || 14;
/// Hidden row that carries what the tenant is willing to agree to.
const GOALS_TYPE = 'ai_goals';
/// Hidden row written once a landlord has agreed, so the good news is told
/// exactly once however many times this loop runs afterwards.
const DEAL_TYPE = 'ai_deal';

/// Conversations answered in this process, so two ticks cannot both reply to
/// the same landlord message while the first is still writing.
const inFlight = new Set();

function lastLandlordSpoke(messages, tenantEmail) {
    const visible = messages.filter(m => m.message_type !== GOALS_TYPE && m.message_type !== DEAL_TYPE);
    if (!visible.length) return null;
    const last = visible[visible.length - 1];
    return (last.sender_email || '').toLowerCase() === tenantEmail ? null : last;
}

async function replyFor(supabase, baseUrl, conversation, notifyNewMessage) {
    const tenant = (conversation.sender_email || '').toLowerCase();
    const landlord = (conversation.receiver_email || '').toLowerCase();
    if (!tenant || !landlord) return;

    const { data: messages } = await supabase
        .from('messages')
        .select('id, sender_email, content, message_type, created_at')
        .eq('conversation_id', conversation.id)
        .order('created_at', { ascending: true })
        .limit(60);

    if (!messages?.length) return;

    const landlordTurn = lastLandlordSpoke(messages, tenant);
    if (!landlordTurn) return;

    // Already agreed. Nothing left to argue about, and re-announcing it every
    // few seconds would be its own bug.
    if (messages.some(m => m.message_type === DEAL_TYPE)) return;

    const ours = messages.filter(m =>
        (m.sender_email || '').toLowerCase() === tenant
        && m.message_type !== GOALS_TYPE && m.message_type !== DEAL_TYPE);
    if (ours.length >= MAX_AI_MESSAGES) return;

    // What the tenant told the app they wanted, stored when the negotiation
    // started. Without it the model would argue with no ceiling at all, which
    // is worse than not answering.
    const goalsRow = messages.find(m => m.message_type === GOALS_TYPE);
    let tenantParams = {};
    if (goalsRow?.content) {
        try { tenantParams = JSON.parse(goalsRow.content) || {}; } catch (_) { /* not json */ }
    }

    let listing = {};
    if (conversation.listing_id) {
        const { data: row } = await supabase
            .from('listings')
            .select('title, price, city')
            .eq('id', conversation.listing_id)
            .maybeSingle();
        if (row) listing = { title: row.title, price: row.price, city: row.city };
    }

    const history = messages
        .filter(m => m.message_type !== GOALS_TYPE && m.message_type !== DEAL_TYPE)
        .map(m => ({
            sender: (m.sender_email || '').toLowerCase() === tenant ? 'ai' : 'landlord',
            content: m.content || ''
        }));

    const response = await fetch(`${baseUrl}/api/negotiate/reply`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            listing,
            tenantParams,
            messageHistory: history,
            lastLandlordMessage: landlordTurn.content || '',
            userEmail: tenant
        })
    });

    if (!response.ok) {
        console.warn(`🤝 negotiator: reply refused (${response.status}) for ${conversation.id}`);
        return;
    }

    const body = await response.json().catch(() => null);
    const text = String(body?.reply || body?.response || body?.message || '').trim();
    if (!text) return;

    const { error } = await supabase.from('messages').insert({
        conversation_id: conversation.id,
        sender_email: tenant,
        content: text
    });
    if (error) {
        console.error('🤝 negotiator: could not post reply:', error.message);
        return;
    }

    console.log(`🤝 negotiator answered ${conversation.id} on behalf of ${tenant}`);
    // The landlord is a person waiting on an answer, so they still get told.
    try { await notifyNewMessage(supabase, conversation.id, tenant); } catch (_) { /* push is optional */ }

    // The whole point of walking away. Detecting the agreement used to happen
    // on the phone, in the same call that wrote the reply — so moving the
    // arguing to the server quietly took the good news with it, and a landlord
    // could agree while the tenant was told nothing at all.
    if (body?.dealClosed) {
        await announceDeal(supabase, conversation, tenant, listing, body);
    }
}

async function announceDeal(supabase, conversation, tenant, listing, outcome) {
    const price = Number(outcome.agreedPrice) || null;
    const viewing = outcome.viewingWhen || null;
    const saved = Number(outcome.savedVsAsking) || 0;

    // Written first, so a failed push cannot cause it to be announced twice.
    await supabase.from('messages').insert({
        conversation_id: conversation.id,
        sender_email: tenant,
        message_type: DEAL_TYPE,
        content: JSON.stringify({
            room: listing?.title || 'the room',
            price,
            viewing,
            savedPerMonth: saved || null,
            agreedAt: new Date().toISOString()
        })
    });

    const room = listing?.title || 'the room';
    const title = price ? `Agreed at $${price}/mo` : 'The landlord agreed';
    const body = [
        room,
        saved ? `$${saved} a month under asking` : null,
        viewing ? `Viewing ${viewing}` : null
    ].filter(Boolean).join(' · ');

    console.log(`🎉 negotiator closed ${conversation.id}: ${title} — ${body}`);
    try {
        await sendToUser(supabase, tenant, {
            title,
            body,
            url: `ai-negotiator.html?conversation=${conversation.id}`
        });
    } catch (e) {
        console.warn('🎉 could not push the agreement:', e.message);
    }
}

async function tick(supabase, baseUrl, notifyNewMessage) {
    const { data: conversations, error } = await supabase
        .from('conversations')
        .select('id, listing_id, sender_email, receiver_email, ai_managed')
        .eq('ai_managed', true)
        .order('created_at', { ascending: false })
        .limit(100);

    if (error) {
        console.error('🤝 negotiator: could not list conversations:', error.message);
        return;
    }
    if (!conversations?.length) return;

    for (const conversation of conversations) {
        if (inFlight.has(conversation.id)) continue;
        inFlight.add(conversation.id);
        try {
            await replyFor(supabase, baseUrl, conversation, notifyNewMessage);
        } catch (e) {
            console.error('🤝 negotiator: failed on', conversation.id, e.message);
        } finally {
            inFlight.delete(conversation.id);
        }
    }
}

function startNegotiatorDaemon({ getSupabase, baseUrl, notifyNewMessage }) {
    if (process.env.NEGOTIATOR_DAEMON === 'off') {
        console.log('🤝 negotiator daemon disabled by NEGOTIATOR_DAEMON=off');
        return;
    }
    console.log(`🤝 negotiator daemon on, every ${Math.round(TICK_MS / 1000)}s`);

    setInterval(() => {
        const supabase = getSupabase();
        if (!supabase) return;
        tick(supabase, baseUrl, notifyNewMessage).catch(e =>
            console.error('🤝 negotiator tick failed:', e.message));
    }, TICK_MS);
}

module.exports = { startNegotiatorDaemon, GOALS_TYPE, DEAL_TYPE };
