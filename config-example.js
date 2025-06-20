// Example configuration file
// Copy this to config.js and fill in your actual API keys
// DO NOT commit config.js with real API keys to git

const config = {
    // Stripe Configuration
    STRIPE_SECRET_KEY: 'sk_test_your_stripe_secret_key_here',
    STRIPE_PUBLISHABLE_KEY: 'pk_test_your_stripe_publishable_key_here',
    
    // Google Maps API Configuration
    GOOGLE_API_KEY: 'your_google_maps_api_key_here',
    
    // Supabase Configuration
    SUPABASE_URL: 'https://your-project.supabase.co/',
    SUPABASE_ANON_KEY: 'your_supabase_anon_key_here',
    
    // OpenAI Configuration
    OPENAI_API_KEY: 'sk-proj-your_openai_api_key_here',
    OPENAI_ORG_ID: 'org-your_openai_org_id_here',
    OPENAI_MODEL: 'gpt-3.5-turbo',
    
    // Other API Keys (add as needed)
    // Add your other API keys here following the same pattern
};

// Export for Node.js (CommonJS)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = config;
}

// Export for ES Modules
if (typeof exports !== 'undefined') {
    exports.config = config;
    exports.default = config;
}

// Export for browser (frontend)
if (typeof window !== 'undefined') {
    window.config = config;
}