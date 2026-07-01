/**
 * Load Supabase credentials from /api/config and initialize the client.
 * Sets window.supabaseConfigReady (Promise) for scripts that need to await init.
 */
(function () {
    window.AppConfig = window.AppConfig || { supabase: null };

    window.supabaseConfigReady = (async function initSupabaseFromApiConfig() {
        if (typeof supabase === 'undefined') {
            console.warn('Supabase library not loaded');
            return null;
        }

        const response = await fetch('/api/config', {
            headers: { 'Cache-Control': 'no-cache' }
        });

        if (!response.ok) {
            throw new Error('Failed to load /api/config: ' + response.status);
        }

        const config = await response.json();

        if (!config.SUPABASE_URL || !config.SUPABASE_ANON_KEY) {
            throw new Error('Missing SUPABASE_URL or SUPABASE_ANON_KEY in /api/config');
        }

        const client = supabase.createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);
        window.AppConfig.supabase = client;
        window.supabase = client;
        window.SUPABASE_URL = config.SUPABASE_URL;
        window.SUPABASE_ANON_KEY = config.SUPABASE_ANON_KEY;
        if (config.GOOGLE_API_KEY) {
            window.GOOGLE_API_KEY = config.GOOGLE_API_KEY;
        }

        return client;
    })().catch(function (error) {
        console.error('Supabase config init failed:', error);
        return null;
    });
})();
