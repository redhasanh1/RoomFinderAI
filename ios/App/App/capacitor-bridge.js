// Capacitor Bridge for iOS API Integration
// This file should be included in your web assets and loaded in the app

import { Capacitor } from '@capacitor/core';
import { registerPlugin } from '@capacitor/core';

// Register our custom bridge plugin
const CapacitorBridge = registerPlugin('CapacitorBridge');

// MARK: - API Configuration Manager
class iOSAPIManager {
    constructor() {
        this.isNative = Capacitor.isNativePlatform();
        this.apiKeys = new Map();
        this.initialized = false;
    }

    // Initialize API keys and configuration
    async initialize() {
        if (this.initialized) return;

        try {
            if (this.isNative) {
                // Get configuration from native bridge
                const config = await CapacitorBridge.getConfig();
                
                // Store API keys
                for (const [key, value] of Object.entries(config)) {
                    this.apiKeys.set(key, value);
                }

                // Initialize keychain storage
                await CapacitorBridge.initializeApiKeys();
                
                console.log('✅ iOS API Manager initialized with native bridge');
            } else {
                // Web fallback - use environment variables
                this.initializeWebConfig();
                console.log('✅ API Manager initialized for web');
            }
            
            this.initialized = true;
        } catch (error) {
            console.error('❌ Failed to initialize API Manager:', error);
            throw error;
        }
    }

    // Web fallback configuration
    initializeWebConfig() {
        // These would come from your web environment variables
        this.apiKeys.set('SUPABASE_URL', process.env.REACT_APP_SUPABASE_URL || '');
        this.apiKeys.set('SUPABASE_ANON_KEY', process.env.REACT_APP_SUPABASE_ANON_KEY || '');
        this.apiKeys.set('BACKEND_URL', process.env.REACT_APP_BACKEND_URL || '');
        this.apiKeys.set('OPENAI_API_KEY', process.env.REACT_APP_OPENAI_API_KEY || '');
    }

    // Get API key
    async getApiKey(keyName) {
        if (!this.initialized) await this.initialize();

        if (this.isNative) {
            try {
                const result = await CapacitorBridge.getApiKey({ key: keyName });
                return result.value;
            } catch (error) {
                // Try stored key if not in config
                try {
                    const stored = await CapacitorBridge.getStoredApiKey({ key: keyName });
                    return stored.value;
                } catch (storageError) {
                    console.warn(`API key not found: ${keyName}`);
                    return null;
                }
            }
        } else {
            return this.apiKeys.get(keyName) || null;
        }
    }

    // Store API key securely
    async setApiKey(keyName, keyValue) {
        if (this.isNative) {
            try {
                await CapacitorBridge.setApiKey({ key: keyName, value: keyValue });
                this.apiKeys.set(keyName, keyValue);
                return true;
            } catch (error) {
                console.error(`Failed to store API key ${keyName}:`, error);
                return false;
            }
        } else {
            this.apiKeys.set(keyName, keyValue);
            return true;
        }
    }

    // Make HTTP request with proper handling for native vs web
    async makeRequest(url, options = {}) {
        if (!this.initialized) await this.initialize();

        const {
            method = 'GET',
            headers = {},
            body = null,
            useAuth = true
        } = options;

        if (this.isNative) {
            // Use native bridge for iOS
            try {
                const requestData = {
                    url: url,
                    method: method,
                    headers: headers,
                    data: body ? (typeof body === 'string' ? JSON.parse(body) : body) : null
                };

                const response = await CapacitorBridge.makeApiRequest(requestData);
                return {
                    ok: true,
                    status: 200,
                    json: async () => response,
                    text: async () => JSON.stringify(response)
                };
            } catch (error) {
                throw new Error(`Native request failed: ${error}`);
            }
        } else {
            // Use standard fetch for web
            const fetchOptions = {
                method,
                headers: {
                    'Content-Type': 'application/json',
                    ...headers
                }
            };

            if (body) {
                fetchOptions.body = typeof body === 'string' ? body : JSON.stringify(body);
            }

            return fetch(url, fetchOptions);
        }
    }

    // Test connection to backend
    async testConnection() {
        if (this.isNative) {
            try {
                const result = await CapacitorBridge.testConnection();
                return result;
            } catch (error) {
                return { status: 'failed', message: error.message };
            }
        } else {
            try {
                const backendUrl = await this.getApiKey('BACKEND_URL');
                const response = await fetch(`${backendUrl}/health`);
                
                if (response.ok) {
                    return { status: 'connected', message: 'Backend connection successful' };
                } else {
                    return { status: 'failed', message: `HTTP ${response.status}` };
                }
            } catch (error) {
                return { status: 'failed', message: error.message };
            }
        }
    }

    // Get environment information
    async getEnvironmentInfo() {
        if (this.isNative) {
            try {
                return await CapacitorBridge.getEnvironmentInfo();
            } catch (error) {
                return { platform: 'ios', isNative: true, error: error.message };
            }
        } else {
            return {
                platform: 'web',
                isNative: false,
                userAgent: navigator.userAgent,
                url: window.location.href
            };
        }
    }
}

// MARK: - API Service Wrapper
class UnifiedAPIService {
    constructor() {
        this.apiManager = new iOSAPIManager();
    }

    async initialize() {
        await this.apiManager.initialize();
    }

    // Supabase integration
    async createSupabaseClient() {
        const supabaseUrl = await this.apiManager.getApiKey('SUPABASE_URL');
        const supabaseKey = await this.apiManager.getApiKey('SUPABASE_ANON_KEY');

        if (!supabaseUrl || !supabaseKey) {
            throw new Error('Supabase configuration missing');
        }

        // Return configuration for Supabase client
        return {
            url: supabaseUrl,
            key: supabaseKey,
            options: {
                auth: {
                    persistSession: true,
                    storageKey: 'roomfinder-auth'
                }
            }
        };
    }

    // Backend API calls
    async callBackendAPI(endpoint, options = {}) {
        const backendUrl = await this.apiManager.getApiKey('BACKEND_URL');
        if (!backendUrl) {
            throw new Error('Backend URL not configured');
        }

        const fullUrl = `${backendUrl}${endpoint}`;
        return this.apiManager.makeRequest(fullUrl, options);
    }

    // OpenAI integration
    async callOpenAI(messages, model = 'gpt-3.5-turbo') {
        const openaiKey = await this.apiManager.getApiKey('OPENAI_API_KEY');
        if (!openaiKey) {
            throw new Error('OpenAI API key not available');
        }

        const requestBody = {
            model: model,
            messages: messages,
            temperature: 0.7,
            max_tokens: 1000
        };

        const response = await this.apiManager.makeRequest(
            'https://api.openai.com/v1/chat/completions',
            {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${openaiKey}`,
                    'Content-Type': 'application/json'
                },
                body: requestBody
            }
        );

        if (!response.ok) {
            throw new Error(`OpenAI API error: ${response.status}`);
        }

        return response.json();
    }

    // Property search
    async searchProperties(query, filters = {}) {
        try {
            const response = await this.callBackendAPI('/api/properties/search', {
                method: 'POST',
                body: { query, filters }
            });

            if (!response.ok) {
                throw new Error(`Search failed: ${response.status}`);
            }

            return response.json();
        } catch (error) {
            console.error('Property search failed:', error);
            throw error;
        }
    }

    // User authentication
    async login(email, password) {
        try {
            const response = await this.callBackendAPI('/api/auth/login', {
                method: 'POST',
                body: { email, password }
            });

            if (!response.ok) {
                throw new Error(`Login failed: ${response.status}`);
            }

            return response.json();
        } catch (error) {
            console.error('Login failed:', error);
            throw error;
        }
    }
}

// MARK: - Export for global use
window.iOSAPIManager = iOSAPIManager;
window.UnifiedAPIService = UnifiedAPIService;

// Create global instance
window.apiService = new UnifiedAPIService();

// Initialize on load
document.addEventListener('DOMContentLoaded', async () => {
    try {
        await window.apiService.initialize();
        console.log('✅ Unified API Service ready');
        
        // Dispatch custom event for app initialization
        window.dispatchEvent(new CustomEvent('apiServiceReady'));
    } catch (error) {
        console.error('❌ Failed to initialize API Service:', error);
    }
});

export { iOSAPIManager, UnifiedAPIService };