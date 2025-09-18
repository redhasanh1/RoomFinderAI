/**
 * Configuration Module
 * Handles API configuration loading and Supabase initialization
 */

class ConfigManager {
    constructor() {
        this.SUPABASE_URL = null;
        this.SUPABASE_ANON_KEY = null;
        this.GOOGLE_API_KEY = null;
        this.supabase = null;
        this.isConfigLoaded = false;
        this.isDOMReady = false;
        this.initializationAttempts = 0;
        this.MAX_INIT_ATTEMPTS = 3;
        this.initCallbacks = [];
    }

    /**
     * Load configuration from Railway API
     */
    async loadConfig() {
        try {
            const response = await fetch('/api/config');
            const config = await response.json();

            this.SUPABASE_URL = config.SUPABASE_URL;
            this.SUPABASE_ANON_KEY = config.SUPABASE_ANON_KEY;
            this.GOOGLE_API_KEY = config.GOOGLE_API_KEY;

            console.log('🔧 Config loaded:', {
                hasSupabaseURL: !!this.SUPABASE_URL,
                hasSupabaseKey: !!this.SUPABASE_ANON_KEY,
                hasGoogleKey: !!this.GOOGLE_API_KEY
            });

            // Initialize Supabase client
            this.supabase = window.supabase.createClient(this.SUPABASE_URL, this.SUPABASE_ANON_KEY);
            console.log('📡 Supabase client initialized');

            this.isConfigLoaded = true;
            this.attemptInitialization();

            return config;
        } catch (error) {
            console.error('❌ Failed to load configuration:', error);
            this.showError('Failed to load configuration. Please refresh the page.');
            throw error;
        }
    }

    /**
     * Wait for DOM to be ready
     */
    waitForDOM() {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => {
                console.log('📄 DOM Content Loaded');
                this.isDOMReady = true;
                this.attemptInitialization();
            });
        } else {
            console.log('📄 DOM already ready');
            this.isDOMReady = true;
            this.attemptInitialization();
        }
    }

    /**
     * Safe initialization function with retry mechanism
     */
    attemptInitialization() {
        console.log('🚀 Attempting initialization...', {
            configLoaded: this.isConfigLoaded,
            domReady: this.isDOMReady,
            attempt: this.initializationAttempts + 1
        });

        if (!this.isConfigLoaded || !this.isDOMReady) {
            console.log('⏳ Waiting for prerequisites...');
            return;
        }

        this.initializationAttempts++;

        try {
            console.log(`🔄 Starting initialization attempt ${this.initializationAttempts}/${this.MAX_INIT_ATTEMPTS}`);

            // Execute all registered callbacks
            this.initCallbacks.forEach(callback => {
                try {
                    callback();
                } catch (error) {
                    console.error('Callback error:', error);
                }
            });

            console.log('✅ Initialization completed successfully');
        } catch (error) {
            console.error(`❌ Initialization attempt ${this.initializationAttempts} failed:`, error);

            if (this.initializationAttempts < this.MAX_INIT_ATTEMPTS) {
                console.log(`🔄 Retrying in 1 second... (${this.MAX_INIT_ATTEMPTS - this.initializationAttempts} attempts remaining)`);
                setTimeout(() => {
                    this.attemptInitialization();
                }, 1000);
            } else {
                console.error('💥 All initialization attempts failed. System may not work properly.');
                this.showError('Application initialization failed. Some features may not work. Please refresh the page.');
            }
        }
    }

    /**
     * Register a callback to be executed when initialization is complete
     */
    onInitialized(callback) {
        this.initCallbacks.push(callback);

        // If already initialized, execute immediately
        if (this.isConfigLoaded && this.isDOMReady) {
            try {
                callback();
            } catch (error) {
                console.error('Callback error:', error);
            }
        }
    }

    /**
     * Get Supabase client instance
     */
    getSupabase() {
        return this.supabase;
    }

    /**
     * Get API configuration
     */
    getConfig() {
        return {
            SUPABASE_URL: this.SUPABASE_URL,
            SUPABASE_ANON_KEY: this.SUPABASE_ANON_KEY,
            GOOGLE_API_KEY: this.GOOGLE_API_KEY
        };
    }

    /**
     * Show error message to user
     */
    showError(message) {
        // Create or update error element
        let errorElement = document.getElementById('config-error');
        if (!errorElement) {
            errorElement = document.createElement('div');
            errorElement.id = 'config-error';
            errorElement.className = 'fixed top-4 right-4 bg-red-500 text-white p-4 rounded-lg shadow-lg z-50';
            document.body.appendChild(errorElement);
        }
        errorElement.textContent = message;

        // Auto-hide after 5 seconds
        setTimeout(() => {
            if (errorElement.parentNode) {
                errorElement.parentNode.removeChild(errorElement);
            }
        }, 5000);
    }
}

// Create global instance
window.configManager = new ConfigManager();

// Auto-initialize
window.configManager.loadConfig();
window.configManager.waitForDOM();

export default window.configManager;