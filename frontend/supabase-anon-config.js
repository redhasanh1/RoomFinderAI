/**
 * Supabase Anonymous Configuration
 * 
 * This configures Supabase to work without authentication using only the public anon key.
 * All queries will work without RLS (Row Level Security) restrictions.
 */

import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const SUPABASE_URL = 'https://zmxyysauqtfkvntgtjsm.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM';

// Create Supabase client with anon key
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
        persistSession: false, // Disable session persistence
        autoRefreshToken: false, // Disable token refresh
        detectSessionInUrl: false // Disable URL session detection
    },
    global: {
        headers: {
            'X-Client-Info': 'RoomFinderAI-iOS-WebView'
        }
    }
});

// Make supabase globally available
window.supabase = supabase;

// Export for imports
export { supabase };
export default supabase;

console.log('✅ Supabase configured for anonymous access');

// Test connection
supabase
    .from('listings')
    .select('id')
    .limit(1)
    .then(({ data, error }) => {
        if (error) {
            console.warn('⚠️ Supabase connection test failed:', error.message);
            console.log('💡 This might be due to RLS policies - check your database settings');
        } else {
            console.log('✅ Supabase connection test successful');
        }
    });