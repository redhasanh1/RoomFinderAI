/**
 * Client Configuration Module
 * Handles application configuration, API endpoints, constants, and environment variables
 */

// Global configuration variables
let SUPABASE_URL;
let SUPABASE_ANON_KEY;
let GOOGLE_API_KEY;
let supabase;

// Configuration state tracking
let isConfigLoaded = false;
let configLoadPromise = null;

// API endpoints configuration
const API_ENDPOINTS = {
    CONFIG: '/api/config',
    CITIES: 'https://unpkg.com/cities.json@1.1.0/cities.json',
    TYPO_DICTIONARY: 'https://unpkg.com/typo-js@1.2.3/dictionaries'
};

// Application constants
const APP_CONSTANTS = {
    MAX_INIT_ATTEMPTS: 3,
    MAX_FILE_SIZE: 10 * 1024 * 1024, // 10MB
    CHAT_FILE_SIZE_LIMIT: 5 * 1024 * 1024, // 5MB
    PING_INTERVAL: 30000, // 30 seconds
    CONNECTION_TIMEOUT: 10000, // 10 seconds
    MAX_RECONNECT_ATTEMPTS: 5,
    POLLING_INTERVAL: 3000, // 3 seconds
    REFRESH_THROTTLE: 5000, // 5 seconds
    PROFILE_IMAGES: [
        'https://images.unsplash.com/photo-1494790108755-2616b332c65c?w=150&h=150&fit=crop&crop=face',
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=face',
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&crop=face'
    ]
};

// Configuration error handling
const CONFIG_ERRORS = {
    LOAD_FAILED: 'Failed to load configuration. Please refresh the page.',
    SUPABASE_INIT_FAILED: 'Failed to initialize Supabase client.',
    NETWORK_ERROR: 'Network error while loading configuration.',
    TIMEOUT_ERROR: 'Configuration loading timed out.'
};

/**
 * Load configuration from Railway API with retry mechanism
 * @returns {Promise<Object>} Configuration object
 */
async function loadConfiguration() {
    if (configLoadPromise) {
        return configLoadPromise;
    }

    configLoadPromise = new Promise(async (resolve, reject) => {
        try {
            console.log('🔧 Loading configuration from API...');
            
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), APP_CONSTANTS.CONNECTION_TIMEOUT);

            const response = await fetch(API_ENDPOINTS.CONFIG, {
                signal: controller.signal,
                headers: {
                    'Cache-Control': 'no-cache',
                    'Pragma': 'no-cache'
                }
            });

            clearTimeout(timeoutId);

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const config = await response.json();
            
            // Validate required configuration
            if (!config.SUPABASE_URL || !config.SUPABASE_ANON_KEY) {
                throw new Error('Missing required configuration keys');
            }

            // Set global configuration variables
            SUPABASE_URL = config.SUPABASE_URL;
            SUPABASE_ANON_KEY = config.SUPABASE_ANON_KEY;
            GOOGLE_API_KEY = config.GOOGLE_API_KEY;

            console.log('🔧 Configuration loaded successfully:', {
                hasSupabaseURL: !!SUPABASE_URL,
                hasSupabaseKey: !!SUPABASE_ANON_KEY,
                hasGoogleKey: !!GOOGLE_API_KEY
            });

            // Initialize Supabase client
            await initializeSupabase();

            isConfigLoaded = true;
            resolve(config);

        } catch (error) {
            console.error('❌ Configuration loading failed:', error);
            
            let errorMessage = CONFIG_ERRORS.LOAD_FAILED;
            if (error.name === 'AbortError') {
                errorMessage = CONFIG_ERRORS.TIMEOUT_ERROR;
            } else if (error.message.includes('Failed to fetch')) {
                errorMessage = CONFIG_ERRORS.NETWORK_ERROR;
            }

            reject(new Error(errorMessage));
        }
    });

    return configLoadPromise;
}

/**
 * Initialize Supabase client with error handling
 */
async function initializeSupabase() {
    try {
        if (!window.supabase) {
            throw new Error('Supabase library not loaded');
        }

        supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        
        // Test connection
        const { data, error } = await supabase.from('profiles').select('count').limit(1);
        
        if (error && error.code !== 'PGRST116') { // PGRST116 is "not found" which is acceptable
            console.warn('⚠️ Supabase connection test warning:', error.message);
        }

        console.log('📡 Supabase client initialized successfully');
        window.supabase = supabase; // Make available globally
        
    } catch (error) {
        console.error('❌ Supabase initialization failed:', error);
        throw new Error(CONFIG_ERRORS.SUPABASE_INIT_FAILED);
    }
}

/**
 * Get configuration value with fallback
 * @param {string} key - Configuration key
 * @param {*} defaultValue - Default value if key not found
 * @returns {*} Configuration value
 */
function getConfig(key, defaultValue = null) {
    const config = {
        SUPABASE_URL,
        SUPABASE_ANON_KEY,
        GOOGLE_API_KEY
    };
    
    return config[key] ?? defaultValue;
}

/**
 * Check if configuration is loaded
 * @returns {boolean} True if configuration is loaded
 */
function isConfigurationLoaded() {
    return isConfigLoaded;
}

/**
 * Get Supabase client instance
 * @returns {Object|null} Supabase client or null if not initialized
 */
function getSupabaseClient() {
    return supabase;
}

/**
 * Get API endpoint URL
 * @param {string} endpoint - Endpoint key
 * @returns {string|null} Endpoint URL or null if not found
 */
function getEndpoint(endpoint) {
    return API_ENDPOINTS[endpoint] || null;
}

/**
 * Get application constant
 * @param {string} constant - Constant key
 * @returns {*} Constant value or null if not found
 */
function getConstant(constant) {
    return APP_CONSTANTS[constant] || null;
}

/**
 * Initialize Typo.js for spell checking
 * @returns {Object} Typo instance
 */
function initializeTypo() {
    const typo = new Typo('en_US', false, false, {
        dictionaryPath: API_ENDPOINTS.TYPO_DICTIONARY
    });
    
    // Add custom dictionary words
    const customWords = ['roomfinder', 'wifi', 'appartment', 'condo', 'sublease', 'negoitator'];
    customWords.forEach(word => {
        typo.dictionary[word] = 1;
    });
    
    return typo;
}

/**
 * Show error message to user
 * @param {string} message - Error message to display
 */
function showError(message) {
    // Simple alert for now - can be enhanced with custom notification system
    alert(message);
}

// Export configuration functions
window.ClientConfig = {
    loadConfiguration,
    isConfigurationLoaded,
    getConfig,
    getSupabaseClient,
    getEndpoint,
    getConstant,
    initializeTypo,
    showError,
    
    // Direct access to configuration variables (for backward compatibility)
    get SUPABASE_URL() { return SUPABASE_URL; },
    get SUPABASE_ANON_KEY() { return SUPABASE_ANON_KEY; },
    get GOOGLE_API_KEY() { return GOOGLE_API_KEY; },
    get supabase() { return supabase; }
};

// Legacy global variables for backward compatibility
window.SUPABASE_URL = SUPABASE_URL;
window.SUPABASE_ANON_KEY = SUPABASE_ANON_KEY;
window.GOOGLE_API_KEY = GOOGLE_API_KEY;
window.supabase = supabase;