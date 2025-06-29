// Railway Environment Configuration Template
// Copy this file to config.js and fill in your actual values
// OR set these as environment variables in Railway dashboard

const config = {
    // OpenAI Configuration
    OPENAI_API_KEY: process.env.OPENAI_API_KEY || 'your_openai_api_key_here',
    OPENAI_ORG_ID: process.env.OPENAI_ORG_ID || 'your_openai_org_id_here',
    OPENAI_MODEL: process.env.OPENAI_MODEL || 'gpt-3.5-turbo',
    
    // Supabase Configuration
    SUPABASE_URL: process.env.SUPABASE_URL || 'your_supabase_url_here',
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY || 'your_supabase_anon_key_here',
    
    // Stripe Configuration
    STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY || 'your_stripe_secret_key_here',
    STRIPE_PUBLISHABLE_KEY: process.env.STRIPE_PUBLISHABLE_KEY || 'your_stripe_publishable_key_here',
    
    // Google Maps API Configuration
    GOOGLE_API_KEY: process.env.GOOGLE_API_KEY || 'your_google_maps_api_key_here',
    
    // Brevo Email Service Configuration
    BREVO_API_KEY: process.env.BREVO_API_KEY || 'your_brevo_api_key_here',
    
    // Azure Verification Services Configuration
    AZURE_DOCUMENT_INTELLIGENCE_KEY: process.env.AZURE_DOCUMENT_INTELLIGENCE_KEY || 'your_azure_document_intelligence_key_here',
    AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT: process.env.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT || 'your_azure_document_intelligence_endpoint_here',
    AZURE_FACE_KEY: process.env.AZURE_FACE_KEY || 'your_azure_face_key_here',
    AZURE_FACE_ENDPOINT: process.env.AZURE_FACE_ENDPOINT || 'your_azure_face_endpoint_here'
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