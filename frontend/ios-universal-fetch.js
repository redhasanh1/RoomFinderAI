/**
 * iOS-Compatible Universal Fetch Replacement for RoomFinderAI
 * 
 * This module provides a universal fetch replacement that works on both web and iOS
 * using the @capacitor/http plugin for iOS native networking.
 * 
 * Usage: Replace all fetch() calls with universalFetch()
 */

import { Capacitor } from '@capacitor/core';
import { CapacitorHttp } from '@capacitor/http';

class UniversalFetch {
    constructor() {
        this.isNative = Capacitor.isNativePlatform();
        this.debug = true; // Enable debug logging
        
        if (this.debug) {
            console.log('🌐 UniversalFetch initialized for platform:', this.isNative ? 'iOS Native' : 'Web');
        }
    }

    /**
     * Universal fetch replacement that works on both web and iOS
     * @param {string|URL} url - The URL to fetch
     * @param {Object} options - Fetch options (method, headers, body, etc.)
     * @returns {Promise<Response>} - Promise that resolves to a Response-like object
     */
    async fetch(url, options = {}) {
        const startTime = Date.now();
        
        if (this.debug) {
            console.log('🔍 UniversalFetch request:', {
                url: url.toString(),
                method: options.method || 'GET',
                platform: this.isNative ? 'iOS Native' : 'Web'
            });
        }

        try {
            if (this.isNative) {
                return await this._nativeFetch(url, options);
            } else {
                return await this._webFetch(url, options);
            }
        } catch (error) {
            console.error('❌ UniversalFetch error:', error);
            throw error;
        } finally {
            const duration = Date.now() - startTime;
            if (this.debug) {
                console.log(`⏱️ Request completed in ${duration}ms`);
            }
        }
    }

    /**
     * Native iOS fetch using @capacitor/http
     */
    async _nativeFetch(url, options) {
        const requestOptions = {
            url: url.toString(),
            method: options.method || 'GET',
            headers: options.headers || {},
            data: options.body,
            timeout: options.timeout || 30000,
            connectTimeout: options.connectTimeout || 10000,
            readTimeout: options.readTimeout || 30000
        };

        // Handle different body types
        if (options.body) {
            if (typeof options.body === 'string') {
                requestOptions.data = options.body;
            } else if (options.body instanceof FormData) {
                // For FormData, we need to convert to appropriate format
                requestOptions.data = this._convertFormDataToObject(options.body);
                // Remove content-type header to let the system set it
                delete requestOptions.headers['content-type'];
                delete requestOptions.headers['Content-Type'];
            } else if (options.body instanceof URLSearchParams) {
                requestOptions.data = options.body.toString();
                requestOptions.headers['Content-Type'] = 'application/x-www-form-urlencoded';
            } else {
                requestOptions.data = JSON.stringify(options.body);
                requestOptions.headers['Content-Type'] = 'application/json';
            }
        }

        // Add platform-specific headers
        requestOptions.headers['X-Platform'] = 'iOS';
        requestOptions.headers['User-Agent'] = 'RoomFinderAI/1.0 (iOS)';

        const response = await CapacitorHttp.request(requestOptions);

        // Create a Response-like object
        return this._createResponseObject(response);
    }

    /**
     * Web fetch using standard fetch API
     */
    async _webFetch(url, options) {
        // Add platform-specific headers
        options.headers = options.headers || {};
        options.headers['X-Platform'] = 'Web';
        
        return await fetch(url, options);
    }

    /**
     * Convert FormData to object for native requests
     */
    _convertFormDataToObject(formData) {
        const obj = {};
        for (let [key, value] of formData.entries()) {
            obj[key] = value;
        }
        return obj;
    }

    /**
     * Create a Response-like object from Capacitor HTTP response
     */
    _createResponseObject(capacitorResponse) {
        const response = {
            ok: capacitorResponse.status >= 200 && capacitorResponse.status < 300,
            status: capacitorResponse.status,
            statusText: this._getStatusText(capacitorResponse.status),
            headers: new Headers(capacitorResponse.headers),
            url: capacitorResponse.url,
            
            // Response body methods
            json: async () => {
                if (typeof capacitorResponse.data === 'string') {
                    return JSON.parse(capacitorResponse.data);
                }
                return capacitorResponse.data;
            },
            
            text: async () => {
                if (typeof capacitorResponse.data === 'string') {
                    return capacitorResponse.data;
                }
                return JSON.stringify(capacitorResponse.data);
            },
            
            blob: async () => {
                // For native platforms, we might need to handle this differently
                const text = await response.text();
                return new Blob([text], { type: 'application/octet-stream' });
            },
            
            arrayBuffer: async () => {
                const text = await response.text();
                return new TextEncoder().encode(text).buffer;
            },
            
            clone: () => {
                return this._createResponseObject(capacitorResponse);
            }
        };

        return response;
    }

    /**
     * Get status text from status code
     */
    _getStatusText(status) {
        const statusTexts = {
            200: 'OK',
            201: 'Created',
            204: 'No Content',
            400: 'Bad Request',
            401: 'Unauthorized',
            403: 'Forbidden',
            404: 'Not Found',
            500: 'Internal Server Error',
            502: 'Bad Gateway',
            503: 'Service Unavailable'
        };
        return statusTexts[status] || 'Unknown';
    }
}

// Create singleton instance
const universalFetch = new UniversalFetch();

/**
 * Universal fetch function that works on both web and iOS
 * @param {string|URL} url - The URL to fetch
 * @param {Object} options - Fetch options
 * @returns {Promise<Response>} - Promise that resolves to a Response-like object
 */
export const fetch = (url, options) => universalFetch.fetch(url, options);

/**
 * Export default fetch function
 */
export default fetch;

/**
 * Convenience methods for common HTTP operations
 */
export const httpGet = (url, options = {}) => {
    return fetch(url, { ...options, method: 'GET' });
};

export const httpPost = (url, data, options = {}) => {
    const body = typeof data === 'string' ? data : JSON.stringify(data);
    const headers = {
        'Content-Type': 'application/json',
        ...options.headers
    };
    
    return fetch(url, {
        ...options,
        method: 'POST',
        headers,
        body
    });
};

export const httpPut = (url, data, options = {}) => {
    const body = typeof data === 'string' ? data : JSON.stringify(data);
    const headers = {
        'Content-Type': 'application/json',
        ...options.headers
    };
    
    return fetch(url, {
        ...options,
        method: 'PUT',
        headers,
        body
    });
};

export const httpDelete = (url, options = {}) => {
    return fetch(url, { ...options, method: 'DELETE' });
};

/**
 * Axios-like interface for easier migration
 */
export const axios = {
    get: httpGet,
    post: httpPost,
    put: httpPut,
    delete: httpDelete,
    
    request: (config) => {
        const { url, method = 'GET', data, headers, params } = config;
        
        let requestUrl = url;
        if (params) {
            const searchParams = new URLSearchParams(params);
            requestUrl += (url.includes('?') ? '&' : '?') + searchParams.toString();
        }
        
        return fetch(requestUrl, {
            method,
            headers,
            body: data ? (typeof data === 'string' ? data : JSON.stringify(data)) : undefined
        });
    }
};

/**
 * jQuery-like AJAX interface for easier migration
 */
export const ajax = (options) => {
    const { url, type = 'GET', data, contentType = 'application/json', headers = {} } = options;
    
    if (contentType) {
        headers['Content-Type'] = contentType;
    }
    
    return fetch(url, {
        method: type,
        headers,
        body: data ? (typeof data === 'string' ? data : JSON.stringify(data)) : undefined
    });
};

console.log('✅ iOS Universal Fetch module loaded successfully');