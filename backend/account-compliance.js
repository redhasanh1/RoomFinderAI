/**
 * Account deletion, content reporting, and user blocking.
 *
 * These exist because the App Store requires them, and an app without them is
 * rejected regardless of how well it is built:
 *
 *   5.1.1(v)  An app that lets you create an account must let you delete it
 *             from inside the app. A link to "email support" does not count.
 *   1.2       An app carrying user-generated content — listings, roommate
 *             profiles, messages — must let people report content, block
 *             abusive users, and must act on reports.
 *
 * They are also simply the right thing to have on a marketplace where
 * strangers arrange to live together.
 */

const bcrypt = require('bcryptjs');

/**
 * Every table holding rows keyed to a person's email.
 *
 * Ordered children-before-parents so foreign keys never block a delete. The
 * column differs per table, which is why this is a list of pairs rather than a
 * list of names.
 */
const USER_DATA_TABLES = [
    { table: 'messages', column: 'sender_email' },
    { table: 'sublease_interests', column: 'interested_email' },
    { table: 'sublease_interests', column: 'owner_email' },
    { table: 'sublease_requests', column: 'user_email' },
    { table: 'conversations', column: 'user_email' },
    { table: 'conversations', column: 'other_user_email' },
    { table: 'favorites', column: 'user_email' },
    { table: 'ai_chats', column: 'user_email' },
    { table: 'ai_negotiations', column: 'user_email' },
    { table: 'user_activities', column: 'user_email' },
    { table: 'user_verifications', column: 'user_email' },
    { table: 'user_payment_methods', column: 'user_email' },
    { table: 'bank_information', column: 'user_email' },
    { table: 'govdocs', column: 'user_email' },
    { table: 'subscriptions', column: 'user_email' },
    { table: 'contact_messages', column: 'user_email' },
    { table: 'roommate_profiles', column: 'user_email' },
    { table: 'listings', column: 'user_email' },
    { table: 'profiles', column: 'email' }
];

/**
 * Confirms the caller really is who they say before anything is destroyed.
 *
 * Every other endpoint on this server takes `userEmail` from the request body
 * and believes it. For deletion that would mean anyone could erase anyone's
 * account by typing their address, so identity is re-checked here against a
 * password or a live session token.
 */
async function verifyIdentity(supabase, { email, password, accessToken }) {
    if (!email) return { ok: false, reason: 'Email is required' };

    // A session token proves an active login, which is the only route open to
    // accounts created through Google or Apple — they have no password.
    if (accessToken) {
        const { data, error } = await supabase.auth.getUser(accessToken);
        if (!error && data?.user?.email?.toLowerCase() === email.toLowerCase()) {
            return { ok: true };
        }
        return { ok: false, reason: 'Your session has expired. Please sign in again.' };
    }

    if (!password) return { ok: false, reason: 'Password is required to delete your account' };

    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (!error) return { ok: true };

    // Same fallback the login route uses: some accounts predate Supabase Auth
    // and keep a bcrypt hash on the profile row.
    const { data: profile } = await supabase
        .from('profiles')
        .select('password')
        .eq('email', email)
        .single();

    if (profile?.password && await bcrypt.compare(password, profile.password)) {
        return { ok: true };
    }

    return { ok: false, reason: 'Incorrect password' };
}

/**
 * Deletes the account and everything attached to it.
 *
 * Deliberately continues past individual table failures rather than aborting
 * half-done: leaving someone with a deleted profile but intact listings is
 * worse than a report saying which tables did not clear.
 */
async function deleteAccountData(supabase, email) {
    const failures = [];

    for (const { table, column } of USER_DATA_TABLES) {
        const { error } = await supabase.from(table).delete().eq(column, email);
        // A missing table or column is expected — the schema differs between
        // environments — and is not a failure worth reporting to the user.
        if (error && !/does not exist|schema cache/i.test(error.message || '')) {
            failures.push(`${table}.${column}: ${error.message}`);
        }
    }

    // Finally the auth record itself, so the address can be signed up again.
    try {
        const { data } = await supabase.auth.admin.listUsers();
        const authUser = (data?.users || []).find(
            (u) => u.email?.toLowerCase() === email.toLowerCase()
        );
        if (authUser) {
            const { error } = await supabase.auth.admin.deleteUser(authUser.id);
            if (error) failures.push(`auth: ${error.message}`);
        }
    } catch (e) {
        failures.push(`auth: ${e.message}`);
    }

    return failures;
}

function registerComplianceRoutes(app, getSupabase) {
    /**
     * Guideline 5.1.1(v). Irreversible, and the client says so before calling.
     */
    app.post('/api/account/delete', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) {
            return res.status(503).json({ error: 'Database not connected' });
        }

        const { email, password, accessToken } = req.body || {};

        const identity = await verifyIdentity(supabase, { email, password, accessToken });
        if (!identity.ok) {
            return res.status(401).json({ error: identity.reason });
        }

        const failures = await deleteAccountData(supabase, email);

        if (failures.length) {
            console.error('Account deletion partially failed for', email, failures);
            return res.status(500).json({
                error: 'Your account was only partly deleted. Please contact support so we can finish removing your data.',
                details: failures
            });
        }

        console.log('🗑️  Account deleted:', email);
        res.json({ success: true, message: 'Your account and all associated data have been deleted.' });
    });

    /**
     * Guideline 1.2 — reporting. Stored for review rather than acted on
     * automatically, so a report cannot be used to take down a rival's listing.
     */
    app.post('/api/report', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) {
            return res.status(503).json({ error: 'Database not connected' });
        }

        const { reporterEmail, targetType, targetId, reason, details } = req.body || {};

        if (!targetType || !targetId || !reason) {
            return res.status(400).json({ error: 'targetType, targetId and reason are required' });
        }

        const { error } = await supabase.from('content_reports').insert({
            reporter_email: reporterEmail || null,
            target_type: targetType,
            target_id: String(targetId),
            reason,
            details: details || null,
            status: 'pending'
        });

        if (error) {
            console.error('Failed to store report:', error.message);
            return res.status(500).json({ error: 'Could not submit your report. Please try again.' });
        }

        console.log(`🚩 Report filed: ${targetType} ${targetId} — ${reason}`);
        res.json({
            success: true,
            message: 'Thanks for reporting this. Our team reviews reports within 24 hours.'
        });
    });

    /**
     * Guideline 1.2 — blocking. Takes effect immediately for the person who
     * blocked, which is what "block" has to mean to be worth anything.
     */
    app.post('/api/block', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) {
            return res.status(503).json({ error: 'Database not connected' });
        }

        const { blockerEmail, blockedEmail } = req.body || {};
        if (!blockerEmail || !blockedEmail) {
            return res.status(400).json({ error: 'blockerEmail and blockedEmail are required' });
        }
        if (blockerEmail.toLowerCase() === blockedEmail.toLowerCase()) {
            return res.status(400).json({ error: 'You cannot block yourself' });
        }

        const { error } = await supabase.from('blocked_users').upsert({
            blocker_email: blockerEmail,
            blocked_email: blockedEmail
        }, { onConflict: 'blocker_email,blocked_email' });

        if (error) {
            console.error('Failed to block user:', error.message);
            return res.status(500).json({ error: 'Could not block this user. Please try again.' });
        }

        res.json({ success: true, message: 'You will no longer see messages or listings from this person.' });
    });

    app.post('/api/unblock', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) {
            return res.status(503).json({ error: 'Database not connected' });
        }

        const { blockerEmail, blockedEmail } = req.body || {};
        if (!blockerEmail || !blockedEmail) {
            return res.status(400).json({ error: 'blockerEmail and blockedEmail are required' });
        }

        const { error } = await supabase
            .from('blocked_users')
            .delete()
            .eq('blocker_email', blockerEmail)
            .eq('blocked_email', blockedEmail);

        if (error) {
            return res.status(500).json({ error: 'Could not unblock this user.' });
        }
        res.json({ success: true });
    });

    /** Who this person has blocked, so clients can filter what they show. */
    app.get('/api/blocked', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) {
            return res.status(503).json({ error: 'Database not connected' });
        }

        const { userEmail } = req.query;
        if (!userEmail) return res.status(400).json({ error: 'userEmail is required' });

        const { data, error } = await supabase
            .from('blocked_users')
            .select('blocked_email')
            .eq('blocker_email', userEmail);

        if (error) return res.status(500).json({ error: 'Could not load your block list' });

        res.json({ success: true, blocked: (data || []).map((r) => r.blocked_email) });
    });
}

module.exports = { registerComplianceRoutes, USER_DATA_TABLES, verifyIdentity, deleteAccountData };
