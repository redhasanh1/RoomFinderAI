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
            .select('id, sender_email, content, created_at')
            .eq('conversation_id', conversationId)
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

        res.json({ success: true, data });
    });
}

module.exports = { registerMessagingRoutes, labelForContext, isParticipant, otherParty };
