/**
 * Supabase-only authentication system.
 * Credentials loaded from /api/config (no hardcoded keys).
 */

console.log('SUPABASE-ONLY AUTH SYSTEM LOADING...');

async function ensureSupabaseClient() {
    if (window.supabase && window.supabase.auth) {
        return window.supabase;
    }

    if (window.supabaseConfigReady) {
        await window.supabaseConfigReady;
        if (window.supabase) return window.supabase;
    }

    if (typeof supabase === 'undefined') {
        return null;
    }

    const response = await fetch('/api/config');
    if (!response.ok) {
        throw new Error('Failed to load /api/config');
    }

    const config = await response.json();
    window.supabase = supabase.createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);
    window.AppConfig = window.AppConfig || {};
    window.AppConfig.supabase = window.supabase;
    return window.supabase;
}

async function isUserAuthenticated() {
    try {
        const client = await ensureSupabaseClient();
        if (!client) return false;
        const { data: { session } } = await client.auth.getSession();
        return !!session?.user;
    } catch (error) {
        console.error('Auth check error:', error);
        return false;
    }
}

async function getCurrentUser() {
    try {
        const client = await ensureSupabaseClient();
        if (!client) return null;

        const { data: { session } } = await client.auth.getSession();
        if (!session?.user) return null;

        const { data: profile, error } = await client
            .from('profiles')
            .select('first_name, last_name, email, profile_image_url')
            .eq('email', session.user.email)
            .single();

        if (error) {
            console.warn('Profile fetch error:', error);
            return {
                email: session.user.email,
                firstName: 'User',
                lastName: 'Name'
            };
        }

        return {
            email: profile.email,
            firstName: profile.first_name || 'User',
            lastName: profile.last_name || 'Name',
            profileImage: profile.profile_image_url
        };
    } catch (error) {
        console.error('Error getting current user:', error);
        return null;
    }
}

async function loginUser(email, password) {
    try {
        const client = await ensureSupabaseClient();
        if (!client) throw new Error('Supabase not initialized');

        const { data, error } = await client.auth.signInWithPassword({ email, password });
        if (error) throw error;

        return { success: true, user: data.user };
    } catch (error) {
        console.error('Login error:', error);
        return { success: false, error: error.message };
    }
}

async function logoutUser() {
    try {
        const client = await ensureSupabaseClient();
        if (!client) return;

        const { error } = await client.auth.signOut();
        if (error) throw error;

        try {
            localStorage.removeItem('currentUser');
            localStorage.removeItem('userToken');
        } catch (e) {
            // ignore
        }

        if (window.location.pathname !== '/login.html' && window.location.pathname !== '/') {
            window.location.href = '/login.html';
        }
    } catch (error) {
        console.error('Logout error:', error);
    }
}

async function checkEmailExists(email) {
    try {
        const client = await ensureSupabaseClient();
        if (!client) return false;

        const { data: profile } = await client
            .from('profiles')
            .select('email')
            .eq('email', email)
            .maybeSingle();

        const { data: { session } } = await client.auth.getSession();
        if (session?.user?.email === email) return true;

        return !!profile;
    } catch (error) {
        console.error('Email check error:', error);
        return false;
    }
}

async function initializeAuth() {
    try {
        const client = await ensureSupabaseClient();
        if (!client) {
            console.error('Supabase client not available');
            return false;
        }

        client.auth.onAuthStateChange((event) => {
            if (event === 'SIGNED_OUT') {
                const protectedPaths = ['/profile.html', '/listings.html'];
                if (protectedPaths.includes(window.location.pathname)) {
                    window.location.href = '/login.html';
                }
            }
        });

        return true;
    } catch (error) {
        console.error('Auth initialization error:', error);
        return false;
    }
}

window.UniversalAuthManager = {
    isUserAuthenticated,
    getCurrentUser,
    loginUser,
    logoutUser,
    checkEmailExists,
    initializeAuth
};

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeAuth);
} else {
    initializeAuth();
}

console.log('SUPABASE-ONLY AUTH SYSTEM READY');
