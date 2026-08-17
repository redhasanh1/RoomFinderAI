/**
 * Profiles, read and written through the server.
 *
 * The browser used to talk to this table directly with the anon key, and that
 * key ships in the page source — so every profile was public. Column grants
 * cut off phone numbers, dates of birth, addresses and bios, but `email` had
 * to stay readable because the pages filter on it, which left the table
 * enumerable: one request returned all 30 addresses.
 *
 * The fix is the shape messaging.js already uses. Two endpoints, both scoped
 * to a single person:
 *
 *   GET /api/profiles/me       the caller's own profile, created if missing
 *   GET /api/profiles/display  display fields for ONE address, no listing
 *
 * Neither can return more than one row, so there is nothing to enumerate. The
 * browser is then denied the table outright.
 *
 * Identity still comes from `userEmail` in the request, exactly as the rest of
 * this server works. That is not authorisation — it is containment, and it
 * removes the bulk-export primitive that mattered most.
 */

/** Everything the UI actually renders. Deliberately excludes the sensitive half. */
const SAFE_COLUMNS = 'id, email, first_name, last_name, profile_image, profile_image_url, is_pro, plan, created_at';

/** The shape the pages expect back. */
function toClient(row) {
    if (!row) return null;
    return {
        id: row.id,
        email: row.email,
        first_name: row.first_name,
        last_name: row.last_name,
        // Both spellings exist in the table and different pages read different
        // ones, so hand back both rather than making callers guess.
        profile_image: row.profile_image,
        profile_image_url: row.profile_image_url,
        is_pro: row.is_pro,
        plan: row.plan,
        created_at: row.created_at
    };
}

function registerProfileRoutes(app, getSupabase) {
    /**
     * The caller's own profile.
     *
     * Creates the row when it is missing, because four separate places in the
     * frontend used to do exactly that themselves — a select, then an insert if
     * the select came back empty. Doing it here means the browser needs no
     * write access to the table at all.
     */
    app.get('/api/profiles/me', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) return res.status(503).json({ success: false, message: 'Database not connected' });

        const email = String(req.query.userEmail || '').trim().toLowerCase();
        if (!email) return res.status(400).json({ success: false, message: 'userEmail is required' });

        const { data: existing, error } = await supabase
            .from('profiles')
            .select(SAFE_COLUMNS)
            .eq('email', email)
            .maybeSingle();

        if (error) {
            console.error('Profiles: lookup failed:', error.message);
            return res.status(500).json({ success: false, message: 'Could not load your profile' });
        }

        if (existing) return res.json({ success: true, data: toClient(existing) });

        // Not there yet — make it. onConflict so two tabs racing the first load
        // cannot produce a duplicate-key error.
        const { data: created, error: insertError } = await supabase
            .from('profiles')
            .upsert({ email }, { onConflict: 'email' })
            .select(SAFE_COLUMNS)
            .single();

        if (insertError) {
            console.error('Profiles: create failed:', insertError.message);
            return res.status(500).json({ success: false, message: 'Could not create your profile' });
        }

        res.json({ success: true, data: toClient(created), created: true });
    });

    /**
     * Make sure a profile row exists for an address.
     *
     * Starting a chat used to require both sides to have a row, and the pages
     * created the *other* person's row themselves — so the browser needed
     * insert access to the whole table. This keeps that behaviour and takes the
     * write privilege away.
     *
     * Creates nothing but an email. No caller-supplied names, so this cannot be
     * used to write someone else's profile fields.
     */
    app.post('/api/profiles/ensure', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) return res.status(503).json({ success: false, message: 'Database not connected' });

        const email = String(req.body?.email || '').trim().toLowerCase();
        // Cheap sanity check: this value becomes a row key.
        if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
            return res.status(400).json({ success: false, message: 'A valid email is required' });
        }

        const { data: existing } = await supabase
            .from('profiles')
            .select('id')
            .eq('email', email)
            .maybeSingle();

        if (existing) return res.json({ success: true, created: false });

        const { error } = await supabase
            .from('profiles')
            .upsert({ email }, { onConflict: 'email' });

        if (error) {
            console.error('Profiles: ensure failed:', error.message);
            return res.status(500).json({ success: false, message: 'Could not set up that profile' });
        }

        res.json({ success: true, created: true });
    });

    /**
     * What one other person looks like: a name and an avatar.
     *
     * Takes a single address and answers about that address only. `exists` is
     * here because the pages used to select `email` purely to find out whether
     * a landlord had a profile at all.
     */
    app.get('/api/profiles/display', async (req, res) => {
        const supabase = getSupabase();
        if (!supabase) return res.status(503).json({ success: false, message: 'Database not connected' });

        const email = String(req.query.email || '').trim().toLowerCase();
        if (!email) return res.status(400).json({ success: false, message: 'email is required' });

        const { data, error } = await supabase
            .from('profiles')
            .select('first_name, last_name, profile_image, profile_image_url')
            .eq('email', email)
            .maybeSingle();

        if (error) {
            console.error('Profiles: display lookup failed:', error.message);
            return res.status(500).json({ success: false, message: 'Could not load that profile' });
        }

        // Never 404 — "no profile" is a normal answer here, and a 404 would
        // make the pages log errors for landlords who simply never filled one
        // in. The address is echoed back only because the caller supplied it.
        res.json({
            success: true,
            data: {
                exists: !!data,
                email: data ? email : null,
                first_name: data?.first_name ?? null,
                last_name: data?.last_name ?? null,
                profile_image: data?.profile_image ?? null,
                profile_image_url: data?.profile_image_url ?? null
            }
        });
    });
}

module.exports = { registerProfileRoutes, SAFE_COLUMNS };
