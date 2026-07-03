/**
 * Refresh the live `listings` catalog so every listing has a real photo.
 *
 * What it does (against the REAL live schema, verified by introspection):
 *   1. Removes listings that have NO usable picture:
 *        - media is null / empty, OR
 *        - none of the media image URLs return HTTP 200.
 *   2. Removes the old auto-generated demo rows (title matches the seed pattern
 *      like "Value 2-Bedroom Apartment in Los Angeles") and any previous rows
 *      this script created (marker tag in description) so it is idempotent.
 *   3. Inserts a clean, permanent set of listings, each with real property
 *      photos, spread across several cities.
 *
 * Safety:
 *   - DRY RUN by default. It only reads and prints a plan.
 *   - Pass --apply to actually delete + insert.
 *   - Uses the service role key (bypasses RLS) from the environment. No secrets
 *     are stored in the repo.
 *
 * Run:
 *   node scripts/refresh-listings.js            # dry run, shows the plan
 *   node scripts/refresh-listings.js --apply    # perform the changes
 */
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY =
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.SUPABASE_SERVICE_KEY ||
    process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error('Missing SUPABASE_URL or a Supabase key in the environment (.env).');
    console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY, then re-run.');
    process.exit(1);
}

const APPLY = process.argv.includes('--apply');
const sb = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

// Marker written into the description of every listing this script creates, so
// re-running is idempotent (old catalog rows are replaced, not duplicated).
const CATALOG_TAG = '[rf-catalog]';

// Titles the old generator produced, e.g. "Value 2-Bedroom Apartment in Los Angeles".
const SEED_TITLE_RE = /^(Modern|Value|Premium|Quality)\s+\d+-Bedroom\s+(House|Apartment|Condo|Townhouse)\s+in\s+/i;

const img = (url, name) => ({ url, type: 'image/jpeg', name });

// Verified reachable stock property photos (image/jpeg, HTTP 200).
const PHOTOS = {
    condo: 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=1200&q=80&auto=format&fit=crop',
    condoAlt: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=1200&q=80&auto=format&fit=crop',
    apt: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200&q=80&auto=format&fit=crop',
    aptAlt: 'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1200&q=80&auto=format&fit=crop',
    house: 'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=1200&q=80&auto=format&fit=crop',
    houseAlt: 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=1200&q=80&auto=format&fit=crop',
    house2: 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=1200&q=80&auto=format&fit=crop',
    interior: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1200&q=80&auto=format&fit=crop',
    interior2: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=1200&q=80&auto=format&fit=crop'
};

function buildCatalog(ownerEmail) {
    const base = (o) => ({
        country: 'Canada',
        utilities: 'Not included',
        status: 'active',
        user_email: ownerEmail,
        description: `${o.description} ${CATALOG_TAG}`
    });
    return [
        base({
            title: 'Modern 2-Bedroom Condo in Downtown Toronto',
            price: 2650, city: 'Toronto', street: '18 Yonge St', postalCode: 'M5E 1Z8',
            house_type: 'Condo', bedrooms: 2, bathrooms: 2, furnished: true, parking_spaces: 1,
            pet_policy: 'Cats allowed', available_from: '2026-08-01',
            description: 'Bright corner unit with floor-to-ceiling windows, in-suite laundry, gym and rooftop patio. Steps to Union Station and the waterfront.',
            media: [img(PHOTOS.condo, 'condo-1.jpg'), img(PHOTOS.interior, 'condo-interior.jpg')]
        }),
        base({
            title: 'Bright 1-Bedroom Apartment near U of T',
            price: 1875, city: 'Toronto', street: '245 College St', postalCode: 'M5T 1R5',
            house_type: 'Apartment', bedrooms: 1, bathrooms: 1, furnished: false, parking_spaces: 0,
            pet_policy: 'No pets', available_from: '2026-09-01',
            description: 'Quiet one-bedroom a short walk from campus, hospitals and Kensington Market. Hardwood floors and a large south-facing window.',
            media: [img(PHOTOS.apt, 'apt-1.jpg'), img(PHOTOS.interior2, 'apt-interior.jpg')]
        }),
        base({
            title: 'Student 3-Bedroom House near Waterloo Campus',
            price: 2400, city: 'Waterloo', street: '312 Phillip St', postalCode: 'N2L 3W9',
            house_type: 'House', bedrooms: 3, bathrooms: 2, furnished: true, parking_spaces: 2,
            pet_policy: 'No pets', available_from: '2026-05-01',
            description: 'Fully furnished student house 5 minutes from the University of Waterloo and Laurier. Utilities and high-speed internet included in a shared plan.',
            media: [img(PHOTOS.house, 'house-1.jpg'), img(PHOTOS.houseAlt, 'house-2.jpg')]
        }),
        base({
            title: 'Cozy Studio in Kitsilano, Vancouver',
            price: 1950, city: 'Vancouver', street: '2130 W 4th Ave', postalCode: 'V6K 1N8',
            house_type: 'Apartment', bedrooms: 0, bathrooms: 1, furnished: true, parking_spaces: 0,
            pet_policy: 'Cats allowed', available_from: '2026-07-01',
            description: 'Sunny furnished studio two blocks from the beach. Perfect for a student or young professional who wants the Kits lifestyle.',
            media: [img(PHOTOS.aptAlt, 'studio-1.jpg')]
        }),
        base({
            title: 'Spacious 2-Bedroom Townhouse in Ottawa',
            price: 2200, city: 'Ottawa', street: '76 Bank St', postalCode: 'K1P 5N2',
            house_type: 'Townhouse', bedrooms: 2, bathrooms: 2, furnished: false, parking_spaces: 1,
            pet_policy: 'Pets negotiable', available_from: '2026-08-15',
            description: 'Renovated townhouse in Centretown with a private backyard, close to Carleton and the downtown core.',
            media: [img(PHOTOS.house2, 'townhouse-1.jpg'), img(PHOTOS.interior, 'townhouse-interior.jpg')]
        }),
        base({
            title: 'Renovated 2-Bedroom Apartment in the Plateau, Montreal',
            price: 1780, city: 'Montreal', street: '4321 Rue Saint-Denis', postalCode: 'H2J 2L1',
            house_type: 'Apartment', bedrooms: 2, bathrooms: 1, furnished: false, parking_spaces: 0,
            pet_policy: 'Pets allowed', available_from: '2026-07-01',
            description: 'Classic Plateau apartment with exposed brick, tall ceilings and a balcony overlooking a quiet, tree-lined street.',
            media: [img(PHOTOS.condoAlt, 'plateau-1.jpg')]
        }),
        base({
            title: '3-Bedroom House with Garage in Calgary',
            price: 2350, city: 'Calgary', street: '1204 17 Ave SW', postalCode: 'T2T 0B8',
            house_type: 'House', bedrooms: 3, bathrooms: 2, furnished: false, parking_spaces: 2,
            pet_policy: 'Pets allowed', available_from: '2026-09-01',
            description: 'Detached family home with a double garage, finished basement and a large fenced yard in a friendly SW neighbourhood.',
            media: [img(PHOTOS.houseAlt, 'calgary-1.jpg'), img(PHOTOS.house, 'calgary-2.jpg')]
        }),
        base({
            title: 'Affordable 2-Bedroom near McMaster, Hamilton',
            price: 1650, city: 'Hamilton', street: '89 Emerson St', postalCode: 'L8S 2X6',
            house_type: 'Apartment', bedrooms: 2, bathrooms: 1, furnished: true, parking_spaces: 1,
            pet_policy: 'No pets', available_from: '2026-05-01',
            description: 'Budget-friendly furnished unit a short bus ride from McMaster University, ideal for roommates splitting rent.',
            media: [img(PHOTOS.apt, 'hamilton-1.jpg')]
        })
    ];
}

function reachable(url) {
    return fetch(url, { method: 'GET', headers: { Range: 'bytes=0-0' } })
        .then((r) => r.ok || r.status === 206)
        .catch(() => false);
}

async function listingHasWorkingImage(listing) {
    const media = Array.isArray(listing.media) ? listing.media : [];
    const urls = media
        .map((m) => m && typeof m === 'object' ? m.url : (typeof m === 'string' ? m : null))
        .filter(Boolean);
    if (!urls.length) return false;
    for (const u of urls) {
        if (await reachable(u)) return true;
    }
    return false;
}

async function pickOwnerEmail() {
    // Reuse an existing user email so the FK (listings.user_email -> users.email) holds.
    const { data } = await sb
        .from('listings')
        .select('user_email')
        .not('user_email', 'is', null)
        .limit(50);
    const counts = {};
    (data || []).forEach((r) => { counts[r.user_email] = (counts[r.user_email] || 0) + 1; });
    const sorted = Object.keys(counts).sort((a, b) => counts[b] - counts[a]);
    return sorted[0] || null;
}

(async () => {
    console.log(APPLY ? '=== APPLY MODE (will modify the database) ===' : '=== DRY RUN (no changes) — add --apply to execute ===');

    const { data: existing, error } = await sb
        .from('listings')
        .select('id, title, media, user_email');
    if (error) {
        console.error('Failed to read listings:', error.message);
        process.exit(1);
    }
    console.log(`Found ${existing.length} existing listings.`);

    const toDelete = [];
    for (const l of existing) {
        const isCatalog = typeof l.title === 'string' && buildCatalog('x').some((c) => c.title === l.title);
        const isSeed = SEED_TITLE_RE.test(l.title || '');
        const hasImg = await listingHasWorkingImage(l);
        if (!hasImg || isSeed || isCatalog) {
            toDelete.push({ id: l.id, title: l.title, reason: !hasImg ? 'no working picture' : (isCatalog ? 'previous catalog row' : 'auto-generated demo row') });
        }
    }

    const ownerEmail = await pickOwnerEmail();
    if (!ownerEmail) {
        console.error('Could not find an existing user email to own the new listings.');
        process.exit(1);
    }
    const catalog = buildCatalog(ownerEmail);

    console.log(`\nWill DELETE ${toDelete.length} listing(s):`);
    toDelete.forEach((d) => console.log(`  - "${d.title}"  (${d.reason})`));
    console.log(`\nWill INSERT ${catalog.length} permanent listing(s) owned by ${ownerEmail}:`);
    catalog.forEach((c) => console.log(`  + "${c.title}"  ($${c.price}, ${c.media.length} photo(s))`));

    if (!APPLY) {
        console.log('\nDry run complete. Re-run with --apply to make these changes.');
        return;
    }

    if (toDelete.length) {
        const ids = toDelete.map((d) => d.id);
        const { error: delErr } = await sb.from('listings').delete().in('id', ids);
        if (delErr) { console.error('Delete failed:', delErr.message); process.exit(1); }
        console.log(`\nDeleted ${ids.length} listing(s).`);
    }

    const { data: inserted, error: insErr } = await sb.from('listings').insert(catalog).select('id');
    if (insErr) { console.error('Insert failed:', insErr.message); process.exit(1); }
    console.log(`Inserted ${inserted.length} listing(s).`);

    const { count } = await sb.from('listings').select('*', { count: 'exact', head: true });
    console.log(`\nDone. listings table now has ${count} row(s), all with real photos.`);
})();
