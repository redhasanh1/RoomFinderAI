/**
 * 🔐 SUPABASE-ONLY AUTHENTICATION SYSTEM
 * 
 * Replaces localStorage-based auth with pure Supabase Auth
 * No localStorage dependencies - everything stored server-side
 */

console.log('🔐 SUPABASE-ONLY AUTH SYSTEM LOADING...');

// Initialize Supabase client
const SUPABASE_URL = 'https://fkktwhjybuflxqzopaex.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs';

if (!window.supabase) {
    if (typeof supabase !== 'undefined') {
        window.supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        console.log('✅ Supabase client initialized');
    } else {
        console.warn('⚠️ Supabase library not loaded yet, client will be initialized later');
    }
}

/**
 * Check if user is authenticated via Supabase
 */
async function isUserAuthenticated() {
    try {
        if (!window.supabase) return false;
        const { data: { session } } = await window.supabase.auth.getSession();
        return !!session?.user;
    } catch (error) {
        console.error('Auth check error:', error);
        return false;
    }
}

/**
 * Get current user data from Supabase
 */
async function getCurrentUser() {
    try {
        if (!window.supabase) return null;
        
        const { data: { session } } = await window.supabase.auth.getSession();
        if (!session?.user) return null;
        
        // Get profile data from profiles table
        const { data: profile, error } = await window.supabase
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

/**
 * Login with email and password
 */
async function loginUser(email, password) {
    try {
        if (!window.supabase) throw new Error('Supabase not initialized');
        
        const { data, error } = await window.supabase.auth.signInWithPassword({
            email: email,
            password: password
        });
        
        if (error) throw error;
        
        console.log('✅ User logged in:', data.user.email);
        return { success: true, user: data.user };
        
    } catch (error) {
        console.error('Login error:', error);
        return { success: false, error: error.message };
    }
}

/**
 * Logout user
 */
async function logoutUser() {
    try {
        if (!window.supabase) return;
        
        const { error } = await window.supabase.auth.signOut();
        if (error) throw error;
        
        console.log('✅ User logged out');
        
        // Clear any remaining localStorage (legacy cleanup)
        try {
            localStorage.removeItem('currentUser');
            localStorage.removeItem('userToken');
        } catch (e) {
            // Ignore localStorage errors
        }
        
        // Redirect to login page
        if (window.location.pathname !== '/login.html' && window.location.pathname !== '/') {
            window.location.href = '/login.html';
        }
        
    } catch (error) {
        console.error('Logout error:', error);
    }
}

/**
 * Check for existing email in database
 */
async function checkEmailExists(email) {
    try {
        if (!window.supabase) return false;
        
        // Check profiles table
        const { data: profile } = await window.supabase
            .from('profiles')
            .select('email')
            .eq('email', email)
            .maybeSingle();
            
        // Check auth users
        const { data: { session } } = await window.supabase.auth.getSession();
        if (session?.user?.email === email) return true;
        
        return !!profile;
        
    } catch (error) {
        console.error('Email check error:', error);
        return false;
    }
}

/**
 * Initialize auth system
 */
async function initializeAuth() {
    try {
        console.log('🔄 Initializing Supabase Auth...');
        
        if (!window.supabase) {
            console.error('❌ Supabase client not available');
            // Try to initialize Supabase if library is now loaded
            if (typeof supabase !== 'undefined') {
                window.supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
                console.log('✅ Supabase client initialized on retry');
            } else {
                return false;
            }
        }
        
        // Listen for auth changes
        window.supabase.auth.onAuthStateChange((event, session) => {
            console.log('🔄 Auth state changed:', event, session?.user?.email || 'no user');
            
            if (event === 'SIGNED_OUT') {
                // Redirect to login if on protected page
                const protectedPaths = ['/dashboard.html', '/profile.html', '/listings.html'];
                if (protectedPaths.includes(window.location.pathname)) {
                    window.location.href = '/login.html';
                }
            }
        });
        
        console.log('✅ Supabase Auth initialized');
        return true;
        
    } catch (error) {
        console.error('❌ Auth initialization error:', error);
        return false;
    }
}

// Export functions globally
window.UniversalAuthManager = {
    isUserAuthenticated,
    getCurrentUser,
    loginUser,
    logoutUser,
    checkEmailExists,
    initializeAuth
};

// Auto-initialize
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeAuth);
} else {
    initializeAuth();
}

console.log('✅ SUPABASE-ONLY AUTH SYSTEM READY');