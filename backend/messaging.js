/**
 * Conversations and messages, for the iOS app.
 *
 * The website reads and writes these tables straight from the browser with the
 * anon key. That is also why the audit found 40 private messages readable by
 * anyone holding it — and anyone does, it ships in the page source.
 *
 * Everything here goes through the service key with a participant check, so a
 * caller can only ever see or write to a thread they are actually in. That is
 * a containment measure, not full authorisation: the caller's identity still
 * comes from `userEmail` in the request, exactly as the rest of this server
 * works today. Real sessions are the proper fix.
 */

const { notifyNewMessage } = require('./push');

/** Where a thread came from, for the label shown beside it. */
const CONTEXT_LABELS = {
    listing: 'Listings',
    sublease: 'Sublease',
    roommate: 'RoomPal'
};

function labelForContext(context) {
    return CONTEXT_LABELS[context] || CONTEXT_LABELS.listing;
}

/** The other person in the thread, from the point of view of `email`. */
function otherParty(conversation, email) {
    const me = (email || '').toLowerCase();
    const sender = conversation.sender_email || '';
    const receiver = conversation.receiver_email || '';
    return sender.toLowerCase() === me ? receiver : sender;
}

function isParticipant(conversation, email) {
    const me = (email || '').toLowerCase();
    return [conversation.sender_email, conversation.receiver_email]
        .filter(Boolean)
        .some((address) => address.toLowerCase() === me);
}

function registerMessagingRoutes(app, getSupabase) {
    /**
     * Every thread this person is in, newest activity first, with enough
     * detail to render an inbox without a request per row.
     */
    app.get('/api/conversations', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) return res.status(503).json({ success: false, message: 'Database not connected' });

        const { userEmail } = req.query;
        if (!userEmail) return res.status(400).json({ success: false, message: 'userEmail is required' });

        const { data: conversations, error } = await supabase
            .from('conversations')
            .select('id, listing_id, sender_email, receiver_email, context, last_read_at, created_at')
            .or(`sender_email.eq.${userEmail},receiver_email.eq.${userEmail}`)
            .limit(200);

        if (error) {
            console.error('Failed to load conversations:', error.message);
            return res.status(500).json({ success: false, message: 'Could not load your messages' });
        }

        const rows = conversations || [];
        if (!rows.length) return res.json({ success: true, data: [] });

        // Last message per thread, fetched in one query rather than one per
        // conversation — an inbox of thirty threads would otherwise be thirty
        // round trips.
        const ids = rows.map((c) => c.id);
        const { data: allMessages } = await supabase
            .from('messages')
            .select('conversation_id, sender_email, content, created_at')
            .in('conversation_id', ids)
            .order('created_at', { ascending: false })
            .limit(1000);

        const latest = new Map();
        const unread = new Map();
        for (const message of allMessages || []) {
            if (!latest.has(message.conversation_id)) latest.set(message.conversation_id, message);

            // Unread means: sent by the other person, after we last looked.
            const conversation = rows.find((c) => c.id === message.conversation_id);
            const fromOther = (message.sender_email || '').toLowerCase() !== userEmail.toLowerCase();
            const seenAt = conversation?.last_read_at ? new Date(conversation.last_read_at) : null;
            if (fromOther && (!seenAt || new Date(message.created_at) > seenAt)) {
                unread.set(message.conversation_id, (unread.get(message.conversation_id) || 0) + 1);
            }
        }

        // Listing titles, so a thread reads as "Quiet 1-bed near campus"
        // rather than an opaque id.
        const listingIds = [...new Set(rows.map((c) => c.listing_id).filter(Boolean))];
        const titles = new Map();
        if (listingIds.length) {
            const { data: listings } = await supabase
                .from('listings')
                .select('id, title')
                .in('id', listingIds);
            for (const listing of listings || []) titles.set(listing.id, listing.title);
        }

        const data = rows
            .map((conversation) => {
                const last = latest.get(conversation.id);
                return {
                    id: conversation.id,
                    context: conversation.context || 'listing',
                    contextLabel: labelForContext(conversation.context),
                    otherParty: otherParty(conversation, userEmail),
                    subject: titles.get(conversation.listing_id) || null,
                    lastMessage: last?.content || null,
                    lastMessageAt: last?.created_at || conversation.created_at,
                    unreadCount: unread.get(conversation.id) || 0
                };
            })
            .sort((a, b) => new Date(b.lastMessageAt) - new Date(a.lastMessageAt));

        res.json({ success: true, data });
    });

    /**
     * Find or create the thread between the person asking and a listing's owner.
     *
     * The website creates this row straight from the browser, which is why no
     * endpoint existed. The app cannot: it has no Supabase session, and the
     * table is no longer reachable with the browser key. Without this there was
     * no way for the app to start a negotiation at all — it could only ever
     * chat to an assistant about a room.
     *
     * Idempotent, and deliberately checks both directions: the landlord may
     * have messaged first, and a second row for the same pair would split one
     * conversation into two half-threads.
     */
    app.post('/api/conversations', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) return res.status(503).json({ success: false, message: 'Database not connected' });

        const { listingId, userEmail, managedByAI, goals } = req.body || {};
        if (!listingId || !userEmail) {
            return res.status(400).json({ success: false, message: 'listingId and userEmail are required' });
        }

        const me = String(userEmail).toLowerCase();

        const { data: listing } = await supabase
            .from('listings')
            .select('id, user_email, title')
            .eq('id', listingId)
            .maybeSingle();

        if (!listing) return res.status(404).json({ success: false, message: 'That room no longer exists' });

        const owner = (listing.user_email || '').toLowerCase();
        if (!owner) return res.status(409).json({ success: false, message: 'That room has no owner to message' });
        if (owner === me) {
            return res.status(409).json({ success: false, message: "That's your own listing" });
        }

        const { data: existing } = await supabase
            .from('conversations')
            .select('id')
            .eq('listing_id', listingId)
            .or(`and(sender_email.eq.${me},receiver_email.eq.${owner}),and(sender_email.eq.${owner},receiver_email.eq.${me})`)
            .limit(1);

        if (existing?.length) {
            // A thread opened by hand and later negotiated is still AI-run;
            // one opened by hand stays a normal conversation.
            if (managedByAI) {
                await supabase.from('conversations')
                    .update({ ai_managed: true })
                    .eq('id', existing[0].id);
            }
            return res.json({ success: true, data: { id: existing[0].id, created: false, landlordEmail: owner, listingTitle: listing.title } });
        }

        const { data: created, error } = await supabase
            .from('conversations')
            .insert({
                listing_id: listingId,
                sender_email: me,
                receiver_email: owner,
                context: 'listing',
                ai_managed: !!managedByAI
            })
            .select('id')
            .single();

        // What the tenant is willing to agree to, kept with the conversation.
        //
        // The goals lived only on the phone, so the server had no idea what it
        // was allowed to offer and the whole negotiation had to be driven by
        // the app. Stored as a hidden message rather than a column because the
        // schema is applied by hand and this needs to work today; it is
        // filtered out of every message list below.
        if (!error && created?.id && managedByAI && goals && typeof goals === 'object') {
            await supabase.from('messages').insert({
                conversation_id: created.id,
                sender_email: me,
                message_type: 'ai_goals',
                content: JSON.stringify(goals)
            });
        }

        if (error) {
            console.error('Failed to create conversation:', error.message);
            return res.status(500).json({ success: false, message: 'Could not start that conversation' });
        }

        res.json({ success: true, data: { id: created.id, created: true, landlordEmail: owner, listingTitle: listing.title } });
    });

    /**
     * Find or create the thread with the person behind a RoomPal profile.
     *
     * RoomPal had no messaging endpoint at all, so the app's "Get in touch"
     * opened the website's matching page in a web view and left the person to
     * work it out. Threads created here carry context 'roommate', which the
     * inbox already labels as RoomPal.
     *
     * Most seeded profiles have no account behind them. That is answered
     * plainly rather than by opening a thread nobody will ever read.
     */
    app.post('/api/roommate-conversations', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) return res.status(503).json({ success: false, message: 'Database not connected' });

        const { profileId, userEmail } = req.body || {};
        if (!profileId || !userEmail) {
            return res.status(400).json({ success: false, message: 'profileId and userEmail are required' });
        }

        const me = String(userEmail).toLowerCase();

        const { data: profile } = await supabase
            .from('roommate_profiles')
            .select('id, user_id, name')
            .eq('id', profileId)
            .maybeSingle();

        if (!profile) return res.status(404).json({ success: false, message: 'That profile no longer exists' });

        // The link between a roommate profile and an account is stored two
        // different ways depending on when the row was written.
        let owner = null;
        for (const column of ['id', 'user_id']) {
            const { data: account } = await supabase
                .from('profiles')
                .select('email')
                .eq(column, profile.user_id)
                .maybeSingle();
            if (account?.email) { owner = account.email.toLowerCase(); break; }
        }

        if (!owner) {
            return res.status(409).json({
                success: false,
                message: `${profile.name || 'This profile'} isn't linked to an account yet, so they can't receive messages.`
            });
        }
        if (owner === me) {
            return res.status(409).json({ success: false, message: "That's your own profile" });
        }

        const { data: existing } = await supabase
            .from('conversations')
            .select('id')
            .eq('context', 'roommate')
            .or(`and(sender_email.eq.${me},receiver_email.eq.${owner}),and(sender_email.eq.${owner},receiver_email.eq.${me})`)
            .limit(1);

        if (existing?.length) {
            return res.json({ success: true, data: { id: existing[0].id, created: false, otherParty: owner } });
        }

        const { data: created, error } = await supabase
            .from('conversations')
            .insert({ sender_email: me, receiver_email: owner, context: 'roommate' })
            .select('id')
            .single();

        if (error) {
            console.error('Failed to create roommate conversation:', error.message);
            return res.status(500).json({ success: false, message: 'Could not start that conversation' });
        }

        res.json({ success: true, data: { id: created.id, created: true, otherParty: owner } });
    });

    /** The messages in one thread, for a participant only. */
    app.get('/api/messages', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) return res.status(503).json({ success: false, message: 'Database not connected' });

        const { conversationId, userEmail } = req.query;
        if (!conversationId || !userEmail) {
            return res.status(400).json({ success: false, message: 'conversationId and userEmail are required' });
        }

        const { data: conversation } = await supabase
            .from('conversations')
            .select('id, sender_email, receiver_email')
            .eq('id', conversationId)
            .single();

        if (!conversation) return res.status(404).json({ success: false, message: 'Conversation not found' });
        if (!isParticipant(conversation, userEmail)) {
            // Deliberately the same shape as "not found": confirming a thread
            // exists is itself a small leak.
            return res.status(404).json({ success: false, message: 'Conversation not found' });
        }

        const { data, error } = await supabase
            .from('messages')
            .select('id, sender_email, content, created_at, message_type')
            .eq('conversation_id', conversationId)
            .or('message_type.is.null,message_type.neq.ai_goals')
            .order('created_at', { ascending: true })
            .limit(500);

        if (error) return res.status(500).json({ success: false, message: 'Could not load messages' });

        // Opening a thread marks it read, which is what makes the unread badge
        // mean anything.
        await supabase
            .from('conversations')
            .update({ last_read_at: new Date().toISOString() })
            .eq('id', conversationId);

        res.json({ success: true, data: data || [] });
    });

    /** Send a message, for a participant only. */
    app.post('/api/messages', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) return res.status(503).json({ success: false, message: 'Database not connected' });

        const { conversationId, userEmail, content } = req.body || {};
        if (!conversationId || !userEmail || !content?.trim()) {
            return res.status(400).json({ success: false, message: 'conversationId, userEmail and content are required' });
        }

        const { data: conversation } = await supabase
            .from('conversations')
            .select('id, sender_email, receiver_email')
            .eq('id', conversationId)
            .single();

        if (!conversation || !isParticipant(conversation, userEmail)) {
            return res.status(404).json({ success: false, message: 'Conversation not found' });
        }

        const { data, error } = await supabase
            .from('messages')
            .insert({
                conversation_id: conversationId,
                sender_email: userEmail,
                content: content.trim()
            })
            .select('id, sender_email, content, created_at')
            .single();

        if (error) {
            console.error('Failed to send message:', error.message);
            return res.status(500).json({ success: false, message: 'Could not send your message' });
        }

        // Buzz the other person's phone. Deliberately not awaited: a push that
        // is slow, or an APNs key that is missing entirely, must not make
        // sending a message feel broken. The message is already saved.
        notifyNewMessage(supabase, conversationId, userEmail)
            .catch(e => console.error('Push after message send failed:', e.message));

        res.json({ success: true, data });
    });
}

module.exports = { registerMessagingRoutes, labelForContext, isParticipant, otherParty };
