// Configuration for modular listings page
// This file provides configuration constants and initialization

// Supabase Configuration
window.SUPABASE_CONFIG = {
    url: 'https://fkktwhjybuflxqzopaex.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHh4em9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTk3Mjc1MzAsImV4cCI6MjAzNTMwMzUzMH0.2vL0jI_zvCeofhY5DdKLQF2-w3GqfTfvJOpKMTVtlqQ'
};

// API Configuration
window.API_CONFIG = {
    baseUrl: window.location.origin,
    endpoints: {
        listings: '/api/listings',
        favorites: '/api/favorites',
        conversations: '/api/conversations',
        health: '/health'
    }
};

// Application Configuration
window.APP_CONFIG = {
    version: '2.0.0',
    debug: false,
    defaultLocation: 'Toronto, ON',
    pagination: {
        defaultLimit: 20,
        maxLimit: 100
    }
};

// Initialize Supabase client when this script loads
if (typeof window.supabase !== 'undefined' && window.SUPABASE_CONFIG) {
    try {
        window.supabaseClient = window.supabase.createClient(
            window.SUPABASE_CONFIG.url,
            window.SUPABASE_CONFIG.anonKey
        );
        console.log('✅ Supabase client initialized successfully');
    } catch (error) {
        console.error('❌ Failed to initialize Supabase client:', error);
    }
} else {
    console.warn('⚠️ Supabase library not available or config missing');
}

console.log('📋 Configuration loaded successfully');