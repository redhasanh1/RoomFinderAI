/**
 * Load Supabase credentials from /api/config and initialize the client.
 * Sets window.supabaseConfigReady (Promise) for scripts that need to await init.
 */
(function () {
    window.AppConfig = window.AppConfig || { supabase: null };

    window.supabaseConfigReady = (async function initSupabaseFromApiConfig() {
        // Already initialized (this script or another ran first) — reuse the client.
        if (window.AppConfig.supabase) {
            return window.AppConfig.supabase;
        }

        // Resolve the Supabase UMD library. Note: on some pages other code sets
        // window.supabase to the *client* instance (which has no createClient),
        // so keep a stable reference to the real library under window.supabaseLib.
        var supabaseLib = window.supabaseLib
            || (window.supabase && typeof window.supabase.createClient === 'function' ? window.supabase : null);

        if (!supabaseLib || typeof supabaseLib.createClient !== 'function') {
            console.warn('Supabase library not loaded yet');
            return null;
        }
        window.supabaseLib = supabaseLib;

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

        const client = supabaseLib.createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);
        window.AppConfig.supabase = client;
        window.supabaseClient = client;
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
