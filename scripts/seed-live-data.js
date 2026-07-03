/**
 * Seed live Supabase with test data for features that are empty.
 * Uses the REAL live schema (verified by introspection), not the repo migrations.
 *
 * - Idempotent: deletes its own seed rows first (marker: seed email / [seed] tag).
 * - Does NOT touch the 10 existing listings (avoids duplicates per request).
 * - Service role bypasses RLS. Run: node scripts/seed-live-data.js
 */
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const SEED_EMAIL_DOMAIN = '@roomfinderai.test';

async function seedSublease() {
    await sb.from('sublease_requests').delete().like('user_email', `%${SEED_EMAIL_DOMAIN}`);
    const rows = [
        {
            user_email: `seed.alex${SEED_EMAIL_DOMAIN}`, type: 'transfer', status: 'active',
            title: 'Summer Sublet — Downtown Toronto 1BR', description: 'Leaving for a summer co-op, need someone to take over my furnished lease May–Aug.',
            address: '88 Harbour St', city: 'Toronto', state: 'ON', zip_code: 'M5J 0C3',
            rent_amount: 2150, utilities_included: true, security_deposit: 2150,
            available_from: '2026-05-01', available_until: '2026-08-31', duration_months: 4, flexible_dates: true,
            property_type: 'condo', bedrooms: 1, bathrooms: 1.0, square_feet: 620, furnished: true,
            amenities: ['gym', 'laundry', 'concierge', 'wifi'], pet_friendly: false, smoking_allowed: false,
            cleanliness_level: 4, noise_tolerance: 3, social_level: 3, schedule_type: 'regular', work_from_home: true,
            urgency_level: 4, contact_method: 'platform'
        },
        {
            user_email: `seed.maria${SEED_EMAIL_DOMAIN}`, type: 'seeking', status: 'active',
            title: 'Grad Student Seeking 8-Month Sublet', description: 'Incoming grad student looking for a quiet furnished room near U of T, Sept–Apr.',
            city: 'Toronto', state: 'ON', min_budget: 900, max_budget: 1500, utilities_included: true,
            available_from: '2026-09-01', available_until: '2027-04-30', duration_months: 8, flexible_dates: true,
            property_type: 'apartment', bedrooms: 1, bathrooms: 1.0, furnished: true,
            amenities: ['wifi', 'quiet', 'furnished'], pet_friendly: false, smoking_allowed: false,
            cleanliness_level: 5, noise_tolerance: 2, social_level: 2, schedule_type: 'early_bird', work_from_home: true,
            urgency_level: 3, contact_method: 'platform'
        },
        {
            user_email: `seed.james${SEED_EMAIL_DOMAIN}`, type: 'transfer', status: 'active',
            title: 'Waterloo Co-op Term Sublet — Studio', description: 'Off for a work term, subletting my furnished studio 5 min from campus.',
            address: '256 Phillip St', city: 'Waterloo', state: 'ON', zip_code: 'N2L 6B6',
            rent_amount: 1250, utilities_included: true, security_deposit: 1250,
            available_from: '2026-01-01', available_until: '2026-04-30', duration_months: 4, flexible_dates: false,
            property_type: 'studio', bedrooms: 0, bathrooms: 1.0, square_feet: 400, furnished: true,
            amenities: ['wifi', 'furnished', 'utilities'], pet_friendly: false, smoking_allowed: false,
            cleanliness_level: 4, noise_tolerance: 3, social_level: 3, schedule_type: 'night_owl', work_from_home: true,
            urgency_level: 5, contact_method: 'platform'
        }
    ];
    const { data, error } = await sb.from('sublease_requests').insert(rows).select('id');
    return { ok: !error, count: data ? data.length : 0, error: error && error.message };
}

async function ensureSeedAuthUser(email) {
    // Create a dedicated auth user (or reuse if it already exists) to satisfy the FK.
    const { data: created, error } = await sb.auth.admin.createUser({
        email, email_confirm: true, user_metadata: { seed: true }
    });
    if (!error && created && created.user) return created.user.id;
    // Already exists — find the id by paging through users.
    let page = 1;
    while (page <= 10) {
        const { data: list } = await sb.auth.admin.listUsers({ page, perPage: 200 });
        if (!list || !list.users || !list.users.length) break;
        const found = list.users.find(u => u.email === email);
        if (found) return found.id;
        page++;
    }
    return null;
}

async function seedRoommates() {
    // Real columns: id, user_id (NOT NULL, FK auth.users), user_type, name, budget_min,
    // budget_max, preferred_areas, move_in_date, bio, avatar_url, lifestyle,
    // compatibility_scores, room_*, is_active
    await sb.from('roommate_profiles').delete().like('bio', '%[seed]%');
    // Valid user_type values (from frontend/js/roommate-api.js): 'seeking', 'has_spot'
    const defs = [
        ['Alex Morgan', 'seeking', 900, 1500, ['Toronto'], 'Tidy, easy-going dev, hybrid work, quiet weeknights.',
            { cleanliness: 8, noiseLevel: 3, socialLevel: 6, smokingPolicy: 1, petPolicy: 6 }, {}],
        ['Maria Santos', 'seeking', 800, 1300, ['Toronto'], 'Grad student, early riser, very organized.',
            { cleanliness: 9, noiseLevel: 2, socialLevel: 4, smokingPolicy: 1, petPolicy: 3 }, {}],
        ['James Chen', 'seeking', 700, 1200, ['Waterloo'], 'Co-op student, night owl, social but respectful.',
            { cleanliness: 6, noiseLevel: 5, socialLevel: 8, smokingPolicy: 1, petPolicy: 9 }, {}],
        ['Priya Sharma', 'has_spot', 1000, 1700, ['Vancouver'], 'Nurse on rotating shifts, clean and quiet. Room available.',
            { cleanliness: 9, noiseLevel: 2, socialLevel: 5, smokingPolicy: 1, petPolicy: 2 },
            { room_rent: 1100, room_location: 'Vancouver', room_available_date: '2026-06-01', room_description: 'Private furnished room, utilities included.' }]
    ];
    const rows = [];
    for (let i = 0; i < defs.length; i++) {
        const [name, user_type, budget_min, budget_max, areas, bio, scores, room] = defs[i];
        const email = `seed.roommate${i + 1}${SEED_EMAIL_DOMAIN}`;
        const user_id = await ensureSeedAuthUser(email);
        if (!user_id) continue;
        rows.push({
            user_id, user_type, name, budget_min, budget_max, preferred_areas: areas,
            move_in_date: '2026-05-01', bio: `${bio} [seed]`, avatar_url: null,
            lifestyle: {}, compatibility_scores: scores, is_active: true, ...room
        });
    }
    if (!rows.length) return { ok: false, count: 0, error: 'no seed auth users created' };
    const { data, error } = await sb.from('roommate_profiles').insert(rows).select('id');
    return { ok: !error, count: data ? data.length : 0, error: error && error.message };
}

async function seedAiNegotiations() {
    await sb.from('ai_negotiations').delete().like('user_email', `%${SEED_EMAIL_DOMAIN}`);
    const rows = [
        {
            user_email: `seed.alex${SEED_EMAIL_DOMAIN}`,
            user_message: 'The listing is $2150/mo. Can you help me negotiate it down?',
            ai_response: 'Comparable 1-beds nearby rent for $1950–$2050, so a fair opening counter is $1975 with a 12-month lease.',
            session_type: 'negotiation_assistant',
            listing_details: { location: 'Toronto', rent: 2150, type: 'Condo', size: '1 bed' },
            tokens_used: 128
        }
    ];
    const { data, error } = await sb.from('ai_negotiations').insert(rows).select('id');
    return { ok: !error, count: data ? data.length : 0, error: error && error.message };
}

(async () => {
    const results = {};
    results.sublease = await seedSublease();
    results.roommates = await seedRoommates();
    // ai_negotiations skipped: live table schema lacks tokens_used (backend log table, non-user-facing).
    for (const [k, v] of Object.entries(results)) {
        console.log(`${k.padEnd(16)} ${v.ok ? 'OK  inserted ' + v.count : 'FAILED: ' + v.error}`);
    }
    // Final counts
    for (const t of ['listings', 'sublease_requests', 'roommate_profiles', 'ai_negotiations']) {
        const { count } = await sb.from(t).select('*', { count: 'exact', head: true });
        console.log(`total ${t.padEnd(20)} ${count}`);
    }
})();
