/**
 * Supabase anonymous configuration for iOS WebView / Capacitor.
 * Loads credentials from /api/config instead of hardcoded keys.
 */
(async function initAnonSupabase() {
    try {
        const response = await fetch('/api/config');
        if (!response.ok) {
            throw new Error('Failed to load /api/config');
        }

        const config = await response.json();
        const { createClient } = await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm');

        const client = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY, {
            auth: {
                persistSession: false,
                autoRefreshToken: false,
                detectSessionInUrl: false
            },
            global: {
                headers: { 'X-Client-Info': 'RoomFinderAI-iOS-WebView' }
            }
        });

        window.supabase = client;
        console.log('Supabase configured for anonymous access via /api/config');
    } catch (error) {
        console.error('Supabase anon config failed:', error);
    }
})();
