/**
 * Profile lookups, through the server.
 *
 * The pages used to query the `profiles` table straight from the browser with
 * the anon key. That key is in the page source, so the table was public and
 * could be dumped for every user's address in one request. The browser is now
 * denied the table, and these two calls are the only way in.
 *
 * Exposed on `window.RoomFinderProfiles` because the callers are a mix of
 * inline page scripts and plain classic scripts — no module system to hang it
 * off.
 */
(function () {
    'use strict';

    // Own profile, keyed by address. Every page asks for this during startup,
    // several of them more than once, and it does not change mid-load.
    const meCache = new Map();
    const displayCache = new Map();

    async function getJSON(url) {
        const response = await fetch(url);
        if (!response.ok) throw new Error('HTTP ' + response.status);
        const body = await response.json();
        if (!body.success) throw new Error(body.message || 'Request failed');
        return body.data;
    }

    /**
     * The signed-in user's profile. Created server-side if it does not exist,
     * so callers no longer need the "select, then insert if empty" dance.
     *
     * Returns null rather than throwing: every existing call site treated a
     * failed profile read as non-fatal, and a rejected promise here would take
     * out page initialisation that used to survive it.
     */
    async function getMyProfile(email, { refresh = false } = {}) {
        const key = String(email || '').trim().toLowerCase();
        if (!key) return null;
        if (!refresh && meCache.has(key)) return meCache.get(key);

        try {
            const profile = await getJSON('/api/profiles/me?userEmail=' + encodeURIComponent(key));
            meCache.set(key, profile);
            return profile;
        } catch (error) {
            console.warn('Could not load your profile:', error.message);
            return null;
        }
    }

    /**
     * Name and avatar for somebody else — a landlord on a listing, the other
     * side of a chat. Always one address at a time; there is no call that
     * returns a list, which is the point.
     *
     * Always resolves to an object, with `exists: false` when there is no
     * profile, because "this landlord never made one" is normal.
     */
    async function getDisplayProfile(email) {
        const key = String(email || '').trim().toLowerCase();
        const empty = { exists: false, email: null, first_name: null, last_name: null, profile_image: null, profile_image_url: null };
        if (!key) return empty;
        if (displayCache.has(key)) return displayCache.get(key);

        try {
            const profile = await getJSON('/api/profiles/display?email=' + encodeURIComponent(key));
            displayCache.set(key, profile);
            return profile;
        } catch (error) {
            console.warn('Could not load that profile:', error.message);
            return empty;
        }
    }

    /** True when the address has a profile. The old code selected `email` for this. */
    async function profileExists(email) {
        const profile = await getDisplayProfile(email);
        return !!profile.exists;
    }

    /** Best available avatar, or null. */
    async function getProfileImage(email) {
        const profile = await getDisplayProfile(email);
        return profile.profile_image_url || profile.profile_image || null;
    }

    /**
     * Make sure a row exists for an address, including somebody else's.
     * Starting a chat needs both sides present, and the pages used to insert
     * the other person's row directly.
     */
    async function ensureProfile(email) {
        const key = String(email || '').trim().toLowerCase();
        if (!key) return false;
        try {
            const response = await fetch('/api/profiles/ensure', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email: key })
            });
            if (!response.ok) throw new Error('HTTP ' + response.status);
            const body = await response.json();
            // A row was just added, so any "no profile" answer we cached is stale.
            if (body.created) displayCache.delete(key);
            return !!body.success;
        } catch (error) {
            console.warn('Could not set up profile for', key, '-', error.message);
            return false;
        }
    }

    /**
     * Display profiles for several addresses at once, for an inbox listing.
     * Still one request per person — the point of this change is that no single
     * request can return a set of people.
     */
    async function getDisplayProfiles(emails) {
        const unique = [...new Set((emails || [])
            .map(e => String(e || '').trim().toLowerCase())
            .filter(Boolean))];

        const results = await Promise.all(unique.map(async email => [email, await getDisplayProfile(email)]));

        const byEmail = {};
        for (const [email, profile] of results) {
            if (profile.exists) byEmail[email] = profile;
        }
        return byEmail;
    }

    /** After a profile edit, so the next read is not the stale cached copy. */
    function clearCache(email) {
        if (email) {
            const key = String(email).trim().toLowerCase();
            meCache.delete(key);
            displayCache.delete(key);
        } else {
            meCache.clear();
            displayCache.clear();
        }
    }

    window.RoomFinderProfiles = {
        getMyProfile,
        getDisplayProfile,
        getDisplayProfiles,
        ensureProfile,
        profileExists,
        getProfileImage,
        clearCache
    };
})();
