// Initialize configuration variables
let SUPABASE_URL;
let SUPABASE_ANON_KEY;
let GOOGLE_API_KEY;
let supabase;

// Global initialization state tracking
let isConfigLoaded = false;
let isDOMReady = false;
let initializationAttempts = 0;
const MAX_INIT_ATTEMPTS = 3;

// Load configuration from Railway API
fetch('/api/config')
    .then(response => response.json())
    .then(config => {
        SUPABASE_URL = config.SUPABASE_URL;
        SUPABASE_ANON_KEY = config.SUPABASE_ANON_KEY;
        GOOGLE_API_KEY = config.GOOGLE_API_KEY;
        
        // Debug config loading
        console.log('🔧 Listings config loaded:', {
            hasSupabaseURL: !!SUPABASE_URL,
            hasSupabaseKey: !!SUPABASE_ANON_KEY,
            hasGoogleKey: !!GOOGLE_API_KEY
        });

        // Initialize Supabase client
        supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        console.log('📡 Supabase client initialized');
        
        isConfigLoaded = true;
        // Only initialize if DOM is also ready
        attemptInitialization();
    })
    .catch(error => {
        console.error('❌ Failed to load configuration:', error);
        showError('Failed to load configuration. Please refresh the page.');
    });

// Wait for DOM to be ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        console.log('📄 DOM Content Loaded');
        isDOMReady = true;
        attemptInitialization();
    });
} else {
    console.log('📄 DOM already ready');
    isDOMReady = true;
    attemptInitialization();
}

// Safe initialization function with retry mechanism
function attemptInitialization() {
    console.log('🚀 Attempting initialization...', {
        configLoaded: isConfigLoaded,
        domReady: isDOMReady,
        attempt: initializationAttempts + 1
    });

    if (!isConfigLoaded || !isDOMReady) {
        console.log('⏳ Waiting for prerequisites...');
        return;
    }

    initializationAttempts++;
    
    try {
        console.log(`🔄 Starting initialization attempt ${initializationAttempts}/${MAX_INIT_ATTEMPTS}`);
        initializeListingsPage();
        console.log('✅ Initialization completed successfully');
    } catch (error) {
        console.error(`❌ Initialization attempt ${initializationAttempts} failed:`, error);
        
        if (initializationAttempts < MAX_INIT_ATTEMPTS) {
            console.log(`🔄 Retrying in 1 second... (${MAX_INIT_ATTEMPTS - initializationAttempts} attempts remaining)`);
            setTimeout(() => {
                attemptInitialization();
            }, 1000);
        } else {
            console.error('💥 All initialization attempts failed. Chat system may not work properly.');
            showError('Application initialization failed. Some features may not work. Please refresh the page.');
        }
    }
}