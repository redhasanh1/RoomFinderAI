/**
 * Capacitor HTTP Service for CORS-free API calls on iOS
 * Compatible with Capacitor 5+, iOS 14+
 */

import { CapacitorHttp } from '@capacitor/core';
import { Capacitor } from '@capacitor/core';

class CapacitorHttpService {
    constructor() {
        this.isCapacitor = Capacitor.isNativePlatform();
        this.baseURL = this.getBaseURL();
        this.defaultHeaders = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        };
        
        console.log('🌐 CapacitorHttpService initialized', {
            isNative: this.isCapacitor,
            baseURL: this.baseURL
        });
    }
    
    getBaseURL() {
        // Detect environment and set appropriate base URL
        if (this.isCapacitor) {
            // Native environment - use your production API
            return 'https://your-api-domain.com';
        } else {
            // Web environment - use relative paths or localhost
            return window.location.origin;
        }
    }
    
    /**
     * Generic HTTP request method
     */
    async request(options) {
        try {
            if (!this.isCapacitor) {
                // Fallback to fetch for web
                return this.fetchFallback(options);
            }
            
            const requestOptions = {
                url: options.url.startsWith('http') ? options.url : `${this.baseURL}${options.url}`,
                method: options.method || 'GET',
                headers: {
                    ...this.defaultHeaders,
                    ...options.headers
                }
            };
            
            // Add body if present
            if (options.data) {
                if (typeof options.data === 'object') {
                    requestOptions.data = options.data;
                } else {
                    requestOptions.data = JSON.parse(options.data);
                }
            }
            
            console.log('📡 Making Capacitor HTTP request:', requestOptions);
            
            const response = await CapacitorHttp.request(requestOptions);
            
            console.log('✅ Capacitor HTTP response:', response);
            
            return {
                data: response.data,
                status: response.status,
                headers: response.headers,
                url: response.url
            };
            
        } catch (error) {
            console.error('❌ Capacitor HTTP error:', error);
            throw new Error(`HTTP Request failed: ${error.message}`);
        }
    }
    
    /**
     * Fallback to fetch for web environments
     */
    async fetchFallback(options) {
        const requestOptions = {
            method: options.method || 'GET',
            headers: {
                ...this.defaultHeaders,
                ...options.headers
            }
        };
        
        if (options.data && (options.method !== 'GET' && options.method !== 'HEAD')) {
            requestOptions.body = typeof options.data === 'string' 
                ? options.data 
                : JSON.stringify(options.data);
        }
        
        const url = options.url.startsWith('http') ? options.url : `${this.baseURL}${options.url}`;
        
        const response = await fetch(url, requestOptions);
        const data = await response.json();
        
        return {
            data,
            status: response.status,
            headers: Object.fromEntries(response.headers.entries()),
            url: response.url
        };
    }
    
    /**
     * GET request
     */
    async get(url, options = {}) {
        return this.request({
            url,
            method: 'GET',
            ...options
        });
    }
    
    /**
     * POST request
     */
    async post(url, data, options = {}) {
        return this.request({
            url,
            method: 'POST',
            data,
            ...options
        });
    }
    
    /**
     * PUT request
     */
    async put(url, data, options = {}) {
        return this.request({
            url,
            method: 'PUT',
            data,
            ...options
        });
    }
    
    /**
     * DELETE request
     */
    async delete(url, options = {}) {
        return this.request({
            url,
            method: 'DELETE',
            ...options
        });
    }
    
    /**
     * PATCH request
     */
    async patch(url, data, options = {}) {
        return this.request({
            url,
            method: 'PATCH',
            data,
            ...options
        });
    }
    
    /**
     * Upload file with progress tracking
     */
    async uploadFile(url, file, options = {}) {
        if (!this.isCapacitor) {
            throw new Error('File upload is only supported in native environments');
        }
        
        try {
            const requestOptions = {
                url: url.startsWith('http') ? url : `${this.baseURL}${url}`,
                method: 'POST',
                headers: {
                    ...options.headers
                },
                data: file
            };
            
            const response = await CapacitorHttp.request(requestOptions);
            return response;
            
        } catch (error) {
            console.error('❌ File upload error:', error);
            throw error;
        }
    }
    
    /**
     * Set authentication token
     */
    setAuthToken(token) {
        this.defaultHeaders['Authorization'] = `Bearer ${token}`;
    }
    
    /**
     * Remove authentication token
     */
    removeAuthToken() {
        delete this.defaultHeaders['Authorization'];
    }
    
    /**
     * Set custom header
     */
    setHeader(key, value) {
        this.defaultHeaders[key] = value;
    }
    
    /**
     * Remove custom header
     */
    removeHeader(key) {
        delete this.defaultHeaders[key];
    }
    
    /**
     * Test connectivity
     */
    async testConnectivity() {
        try {
            const response = await this.get('/health');
            return response.status === 200;
        } catch (error) {
            console.warn('⚠️ Connectivity test failed:', error);
            return false;
        }
    }
}

// Create global instance
const capacitorHttp = new CapacitorHttpService();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { CapacitorHttpService, capacitorHttp };
}

// Make available globally
if (typeof window !== 'undefined') {
    window.capacitorHttp = capacitorHttp;
    window.CapacitorHttpService = CapacitorHttpService;
}

export { CapacitorHttpService, capacitorHttp };