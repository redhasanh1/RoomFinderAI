// Railway Environment Configuration Template
// Copy this file to config.js and fill in your actual values
// OR set these as environment variables in Railway dashboard

const config = {
    // OpenAI Configuration
    OPENAI_API_KEY: process.env.OPENAI_API_KEY,
    OPENAI_ORG_ID: process.env.OPENAI_ORG_ID,
    OPENAI_MODEL: process.env.OPENAI_MODEL || 'gpt-3.5-turbo',
    
    // Supabase Configuration
    SUPABASE_URL: process.env.SUPABASE_URL,
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY,
    
    // Stripe Configuration
    STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY,
    STRIPE_PUBLISHABLE_KEY: process.env.STRIPE_PUBLISHABLE_KEY,
    
    // Google Maps API Configuration
    GOOGLE_API_KEY: process.env.GOOGLE_API_KEY,
    
    // Brevo Email Service Configuration
    BREVO_API_KEY: process.env.BREVO_API_KEY,
    
    // Azure Verification Services Configuration
    AZURE_DOCUMENT_INTELLIGENCE_KEY: process.env.AZURE_DOCUMENT_INTELLIGENCE_KEY,
    AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT: process.env.AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT,
    AZURE_FACE_KEY: process.env.AZURE_FACE_KEY,
    AZURE_FACE_ENDPOINT: process.env.AZURE_FACE_ENDPOINT
};

export default config;