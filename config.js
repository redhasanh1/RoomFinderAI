// Frontend Configuration for Browser
// Uses Railway environment variables - no hardcoded API keys

const config = {
    // Stripe Configuration (client-safe)
    STRIPE_PUBLISHABLE_KEY: process.env.STRIPE_PUBLISHABLE_KEY,
    
    // Google Maps API Key (client-safe)
    GOOGLE_API_KEY: process.env.GOOGLE_API_KEY
};

// Export for browser (frontend)
if (typeof window !== 'undefined') {
    window.config = config;
}

// Export for Node.js if needed
if (typeof module !== 'undefined' && module.exports) {
    module.exports = config;
}