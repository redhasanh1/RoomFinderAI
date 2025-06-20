// Config loader - loads configuration from environment variables or config.js
// This file handles both Railway deployment (env vars) and local development (config.js)

let config;

// Try to load from environment variables first (for Railway deployment)
if (process.env.STRIPE_SECRET_KEY) {
    config = {
        STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY,
        STRIPE_PUBLISHABLE_KEY: process.env.STRIPE_PUBLISHABLE_KEY,
        GOOGLE_API_KEY: process.env.GOOGLE_API_KEY,
        SUPABASE_URL: process.env.SUPABASE_URL,
        SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY,
        OPENAI_API_KEY: process.env.OPENAI_API_KEY,
        OPENAI_ORG_ID: process.env.OPENAI_ORG_ID,
        OPENAI_MODEL: process.env.OPENAI_MODEL || 'gpt-3.5-turbo'
    };
} else {
    // Fallback to local config.js file (for local development)
    try {
        config = require('./config.js');
        console.log('✅ Loaded config from config.js (local development)');
    } catch (error) {
        console.error('❌ Could not load config.js. Please create it from config-example.js');
        console.error('For Railway deployment, set environment variables instead.');
        process.exit(1);
    }
}

module.exports = config;