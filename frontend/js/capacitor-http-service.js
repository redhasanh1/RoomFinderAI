// Capacitor HTTP Service for Native iOS Integration
import { CapacitorHttp } from '@capacitor/core';

class CapacitorHttpService {
    constructor() {
        this.isCapacitor = window.Capacitor && window.Capacitor.isNativePlatform();
        this.baseURL = 'https://roomfinder-ai-negotiator-production.up.railway.app';
    }

    /**
     * Make HTTP request using Capacitor HTTP plugin
     * This ensures proper CORS handling on iOS
     */
    async request(options) {
        if (!this.isCapacitor) {
            // Fallback to fetch for web
            return this.fetchFallback(options);
        }

        try {
            const requestOptions = {
                url: options.url.startsWith('http') ? options.url : `${this.baseURL}${options.url}`,
                method: options.method || 'GET',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    ...options.headers
                },
                data: options.data,
                params: options.params,
                responseType: options.responseType || 'json',
                timeout: options.timeout || 30000,
                connectTimeout: options.connectTimeout || 10000,
                readTimeout: options.readTimeout || 30000
            };

            console.log('🚀 Capacitor HTTP Request:', requestOptions);
            
            const response = await CapacitorHttp.request(requestOptions);
            
            console.log('✅ Capacitor HTTP Response:', response);
            
            return {
                data: response.data,
                status: response.status,
                headers: response.headers,
                config: requestOptions
            };
        } catch (error) {
            console.error('❌ Capacitor HTTP Error:', error);
            throw this.normalizeError(error);
        }
    }

    async get(url, config = {}) {
        return this.request({ ...config, method: 'GET', url });
    }

    async post(url, data, config = {}) {
        return this.request({ ...config, method: 'POST', url, data });
    }

    async put(url, data, config = {}) {
        return this.request({ ...config, method: 'PUT', url, data });
    }

    async delete(url, config = {}) {
        return this.request({ ...config, method: 'DELETE', url });
    }

    async patch(url, data, config = {}) {
        return this.request({ ...config, method: 'PATCH', url, data });
    }

    // Fallback for web platform
    async fetchFallback(options) {
        const url = options.url.startsWith('http') ? options.url : `${this.baseURL}${options.url}`;
        
        const fetchOptions = {
            method: options.method || 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                ...options.headers
            }
        };

        if (options.data && ['POST', 'PUT', 'PATCH'].includes(options.method)) {
            fetchOptions.body = JSON.stringify(options.data);
        }

        const response = await fetch(url, fetchOptions);
        const data = await response.json();

        return {
            data,
            status: response.status,
            headers: Object.fromEntries(response.headers.entries()),
            config: fetchOptions
        };
    }

    normalizeError(error) {
        return {
            message: error.message || 'Network request failed',
            status: error.status || 0,
            data: error.data || null,
            isNetworkError: true
        };
    }

    // Utility method to check if running on iOS
    isIOS() {
        return this.isCapacitor && window.Capacitor.getPlatform() === 'ios';
    }

    // Utility method to get platform info
    getPlatformInfo() {
        if (!this.isCapacitor) {
            return { platform: 'web', isNative: false };
        }
        
        return {
            platform: window.Capacitor.getPlatform(),
            isNative: window.Capacitor.isNativePlatform(),
            version: window.Capacitor.getVersion?.() || 'unknown'
        };
    }
}

// Global instance
window.capacitorHttp = new CapacitorHttpService();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = CapacitorHttpService;
}

export default CapacitorHttpService;