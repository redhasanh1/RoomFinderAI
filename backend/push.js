/**
 * Apple push notifications.
 *
 * The app already had the whole front half of this: the entitlement, the
 * permission prompt, the registration callback, even tap-routing for a payload
 * carrying a url. What it never had was anywhere to put the device token and
 * anything to send. A token was computed on registration, assigned to a
 * property, and dropped — so a landlord could be messaged by a tenant's AI and
 * never find out until they happened to reopen the app. For a product whose
 * pitch is "walk away and let it negotiate", that is the whole feature missing.
 *
 * No new dependency: an APNs push is an HTTP/2 request carrying an ES256 JWT,
 * and node has both built in. `crypto.sign` with `dsaEncoding: 'ieee-p1363'`
 * produces the raw r||s signature JOSE wants, which is the only fiddly part.
 *
 * Everything here no-ops quietly when APNS_* is unset, so a deploy without the
 * key behaves exactly as it does today rather than erroring on every message.
 */

const http2 = require('http2');
const crypto = require('crypto');

const HOSTS = {
    production: 'https://api.push.apple.com',
    development: 'https://api.sandbox.push.apple.com'
};

const BUNDLE_ID = process.env.APNS_BUNDLE_ID?.trim() || 'com.roomfinderai.app';
const TEAM_ID = process.env.APNS_TEAM_ID?.trim();
const KEY_ID = process.env.APNS_KEY_ID?.trim();
// Railway strips newlines from multi-line values, so accept the common
// "\n"-escaped form as well as a real PEM block.
const PRIVATE_KEY = process.env.APNS_PRIVATE_KEY?.replace(/\\n/g, '\n').trim();

const isConfigured = !!(TEAM_ID && KEY_ID && PRIVATE_KEY);

if (!isConfigured) {
    console.warn('🔕 APNs not configured (APNS_TEAM_ID / APNS_KEY_ID / APNS_PRIVATE_KEY) — device tokens will be stored but no pushes sent.');
}

/**
 * APNs provider tokens last an hour and Apple rejects a provider that mints
 * them faster than once every 20 minutes, so this is cached rather than signed
 * per push.
 */
let cachedToken = null;
let cachedAt = 0;
const TOKEN_TTL_MS = 45 * 60 * 1000;

function providerToken() {
    if (cachedToken && Date.now() - cachedAt < TOKEN_TTL_MS) return cachedToken;

    const header = { alg: 'ES256', kid: KEY_ID };
    const claims = { iss: TEAM_ID, iat: Math.floor(Date.now() / 1000) };
    const encode = obj => Buffer.from(JSON.stringify(obj)).toString('base64url');

    const signingInput = `${encode(header)}.${encode(claims)}`;
    const signature = crypto.sign('SHA256', Buffer.from(signingInput), {
        key: PRIVATE_KEY,
        dsaEncoding: 'ieee-p1363'
    }).toString('base64url');

    cachedToken = `${signingInput}.${signature}`;
    cachedAt = Date.now();
    return cachedToken;
}

/**
 * One push to one device. Resolves with the APNs status so the caller can
 * retire tokens Apple has told us are dead.
 */
function sendOne(deviceToken, environment, payload) {
    return new Promise(resolve => {
        const host = HOSTS[environment] || HOSTS.production;
        const client = http2.connect(host);

        // A hung connection must not hold a request open forever.
        const timer = setTimeout(() => {
            try { client.destroy(); } catch (_) { /* already gone */ }
            resolve({ status: 0, reason: 'timeout' });
        }, 10000);

        const finish = result => {
            clearTimeout(timer);
            try { client.close(); } catch (_) { /* already closed */ }
            resolve(result);
        };

        client.on('error', err => finish({ status: 0, reason: err.message }));

        const body = JSON.stringify(payload);
        const request = client.request({
            ':method': 'POST',
            ':path': `/3/device/${deviceToken}`,
            'authorization': `bearer ${providerToken()}`,
            'apns-topic': BUNDLE_ID,
            'apns-push-type': 'alert',
            'apns-priority': '10',
            'content-type': 'application/json',
            'content-length': Buffer.byteLength(body)
        });

        let status = 0;
        let response = '';
        request.on('response', headers => { status = headers[':status']; });
        request.setEncoding('utf8');
        request.on('data', chunk => { response += chunk; });
        request.on('end', () => {
            let reason = null;
            try { reason = JSON.parse(response || '{}').reason || null; } catch (_) { /* not json */ }
            finish({ status, reason });
        });
        request.on('error', err => finish({ status: 0, reason: err.message }));

        request.end(body);
    });
}

/**
 * Push to every device a person has registered.
 *
 * Tokens Apple reports as dead are deleted rather than left to fail forever —
 * a reinstalled app issues a new token and the old one never becomes valid
 * again.
 */
async function sendToUser(supabase, userEmail, { title, body, url, badge } = {}) {
    if (!isConfigured || !supabase || !userEmail) return { sent: 0, skipped: true };

    const { data: devices, error } = await supabase
        .from('device_tokens')
        .select('token, environment')
        .eq('user_email', userEmail.toLowerCase());

    if (error) {
        console.error('Push: could not load device tokens:', error.message);
        return { sent: 0 };
    }
    if (!devices?.length) return { sent: 0 };

    const payload = {
        aps: {
            alert: { title, body },
            sound: 'default',
            ...(typeof badge === 'number' ? { badge } : {})
        },
        ...(url ? { url } : {})
    };

    let sent = 0;
    const dead = [];

    await Promise.all(devices.map(async device => {
        const { status, reason } = await sendOne(device.token, device.environment, payload);
        if (status === 200) { sent++; return; }
        // 410 is Apple saying the app is gone from that device; a 400
        // BadDeviceToken means it was never valid for this topic.
        if (status === 410 || reason === 'BadDeviceToken' || reason === 'Unregistered') {
            dead.push(device.token);
        } else {
            console.warn(`Push failed (${status} ${reason || 'no reason'}) for ${userEmail}`);
        }
    }));

    if (dead.length) {
        await supabase.from('device_tokens').delete().in('token', dead);
        console.log(`🔕 Retired ${dead.length} dead device token(s) for ${userEmail}`);
    }

    return { sent };
}

/**
 * "Someone messaged you" for a thread, addressed to whichever participant did
 * not send it.
 *
 * The text is read back out of the database rather than taken from the caller,
 * so this cannot be used to put arbitrary words on someone's lock screen — the
 * worst a caller can do is re-announce a message that genuinely exists in a
 * conversation they are part of.
 */
async function notifyNewMessage(supabase, conversationId, senderEmail) {
    if (!isConfigured || !supabase || !conversationId) return { sent: 0, skipped: true };

    try {
        const { data: conversation } = await supabase
            .from('conversations')
            .select('id, listing_id, sender_email, receiver_email, ai_managed')
            .eq('id', conversationId)
            .single();

        if (!conversation) return { sent: 0 };

        const from = (senderEmail || '').toLowerCase();
        const participants = [conversation.sender_email, conversation.receiver_email].filter(Boolean);
        const recipient = participants.find(address => address.toLowerCase() !== from);
        if (!recipient) return { sent: 0 };

        // Silence for the side whose AI is running the thread.
        //
        // A tenant negotiating five rooms got a push for every landlord reply,
        // five conversations deep, about messages their negotiator answers on
        // its own within seconds. The app tells them the thing that matters —
        // a landlord agreeing — itself. The landlord still gets every message,
        // because there is a person on that end reading them.
        if (conversation.ai_managed &&
            recipient.toLowerCase() === (conversation.sender_email || '').toLowerCase()) {
            return { sent: 0, skipped: 'ai_managed' };
        }

        // The AI negotiator writes under its own address on the tenant's
        // behalf, so pushing "ai-negotiator@roomfinder.com messaged you" would
        // be both ugly and confusing. The listing is what the landlord
        // recognises.
        const { data: last } = await supabase
            .from('messages')
            .select('content')
            .eq('conversation_id', conversationId)
            .order('created_at', { ascending: false })
            .limit(1)
            .maybeSingle();

        let title = 'New message';
        if (conversation.listing_id) {
            const { data: listing } = await supabase
                .from('listings')
                .select('title')
                .eq('id', conversation.listing_id)
                .maybeSingle();
            if (listing?.title) title = listing.title;
        }

        const preview = String(last?.content || '')
            .split('\n\n———\n\n')[0]
            .trim()
            .slice(0, 180);

        // How many are waiting for them in total, so the number on the icon is
        // right the moment the push lands rather than whenever the app next
        // polls. Without this the badge only appeared after the app had been
        // opened and had asked, which is not what "you have a message" should
        // mean.
        let badge;
        try {
            const { data: theirs } = await supabase
                .from('conversations')
                .select('id, sender_email, receiver_email, sender_last_read_at, receiver_last_read_at, last_read_at')
                .or(`sender_email.eq.${recipient},receiver_email.eq.${recipient}`);

            const ids = (theirs || []).map(c => c.id);
            if (ids.length) {
                const { data: msgs } = await supabase
                    .from('messages')
                    .select('conversation_id, sender_email, created_at')
                    .in('conversation_id', ids);

                badge = (msgs || []).filter((m) => {
                    const c = theirs.find(x => x.id === m.conversation_id);
                    if (!c) return false;
                    if ((m.sender_email || '').toLowerCase() === recipient.toLowerCase()) return false;
                    const seenRaw = (c.sender_email || '').toLowerCase() === recipient.toLowerCase()
                        ? c.sender_last_read_at : c.receiver_last_read_at;
                    const seen = seenRaw || c.last_read_at;
                    return !seen || new Date(m.created_at) > new Date(seen);
                }).length;
            }
        } catch (error) {
            // A badge that cannot be counted must not stop the notification.
            console.warn('Could not count unread for badge:', error.message || error);
        }

        return await sendToUser(supabase, recipient, {
            ...(typeof badge === 'number' ? { badge } : {}),
            title,
            body: preview || 'You have a new message.',
            // `messages.html` has never existed on this site, so tapping a
            // notification opened a 404. Messaging lives on the negotiator
            // page, and in the app that path maps to the Messages tab.
            url: `ai-negotiator.html?conversation=${conversationId}`
        });
    } catch (e) {
        console.error('Push: notifyNewMessage failed:', e.message);
        return { sent: 0 };
    }
}

function registerPushRoutes(app, getSupabase) {
    /**
     * Store a device token against an address. Called by the app every launch
     * once it has both a token and a signed-in user — cheap, and it keeps the
     * mapping right when someone signs into a different account on the same
     * phone.
     */
    app.post('/api/push/register', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) return res.status(503).json({ success: false, message: 'Database not connected' });

        const { userEmail, token, environment } = req.body || {};
        if (!userEmail || !token) {
            return res.status(400).json({ success: false, message: 'userEmail and token are required' });
        }
        // Hex, 64 bytes today, but Apple has changed the length before.
        if (!/^[a-f0-9]{32,200}$/i.test(token)) {
            return res.status(400).json({ success: false, message: 'That is not a device token' });
        }

        const row = {
            token: token.toLowerCase(),
            user_email: String(userEmail).toLowerCase(),
            environment: environment === 'development' ? 'development' : 'production',
            updated_at: new Date().toISOString()
        };

        // The token is the key: one row per device, following whoever is
        // signed in on it. Two people sharing a phone must not both get the
        // other's messages.
        const { error } = await supabase
            .from('device_tokens')
            .upsert(row, { onConflict: 'token' });

        if (error) {
            console.error('Push: register failed:', error.message);
            return res.status(500).json({ success: false, message: 'Could not register for notifications' });
        }

        res.json({ success: true, delivering: isConfigured });
    });

    /** Sign-out, and "turn these off" from the app. */
    app.post('/api/push/unregister', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) return res.status(503).json({ success: false, message: 'Database not connected' });

        const { token } = req.body || {};
        if (!token) return res.status(400).json({ success: false, message: 'token is required' });

        const { error } = await supabase
            .from('device_tokens')
            .delete()
            .eq('token', String(token).toLowerCase());

        if (error) return res.status(500).json({ success: false, message: 'Could not unregister' });
        res.json({ success: true });
    });

    /**
     * Announce a message that was written straight to the database rather than
     * through POST /api/messages — which is every message the web negotiator
     * sends, because the browser talks to Supabase directly.
     *
     * Takes no notification text: it names a conversation, and the server
     * decides what to say from what is actually stored.
     */
    app.post('/api/push/notify-message', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) return res.status(503).json({ success: false, message: 'Database not connected' });

        const { conversationId, senderEmail } = req.body || {};
        if (!conversationId) return res.status(400).json({ success: false, message: 'conversationId is required' });

        const result = await notifyNewMessage(supabase, conversationId, senderEmail);
        res.json({ success: true, ...result });
    });
}

module.exports = { registerPushRoutes, sendToUser, notifyNewMessage, isConfigured };
