/**
 * Capacitor Fetch Interceptor for iOS WebView
 * 
 * This intercepts ALL fetch() calls in your website and routes them through
 * Capacitor's native HTTP plugin for iOS compatibility.
 * 
 * Just include this script in your HTML and all your existing fetch() calls will work!
 */

import { Capacitor } from '@capacitor/core';
import { CapacitorHttp } from '@capacitor/http';

// Only apply the interceptor on native platforms (iOS/Android)
if (Capacitor.isNativePlatform()) {
    console.log('🔄 Capacitor Fetch Interceptor active for iOS');

    // Store the original fetch function
    const originalFetch = window.fetch;

    // Replace the global fetch function
    window.fetch = async function(url, options = {}) {
        try {
            console.log('🌐 Intercepting fetch call to:', url);
            
            // Convert fetch options to CapacitorHttp options
            const httpOptions = {
                url: url.toString(),
                method: options.method || 'GET',
                headers: options.headers || {},
                connectTimeout: 10000,
                readTimeout: 30000
            };

            // Handle request body
            if (options.body) {
                if (typeof options.body === 'string') {
                    httpOptions.data = options.body;
                } else if (options.body instanceof FormData) {
                    // Convert FormData to object
                    const formObject = {};
                    for (let [key, value] of options.body.entries()) {
                        formObject[key] = value;
                    }
                    httpOptions.data = formObject;
                } else if (options.body instanceof URLSearchParams) {
                    httpOptions.data = options.body.toString();
                    httpOptions.headers['Content-Type'] = 'application/x-www-form-urlencoded';
                } else {
                    httpOptions.data = JSON.stringify(options.body);
                    httpOptions.headers['Content-Type'] = 'application/json';
                }
            }

            // Make the request using CapacitorHttp
            const response = await CapacitorHttp.request(httpOptions);

            // Create a Response-like object that matches the Fetch API
            const fetchResponse = {
                ok: response.status >= 200 && response.status < 300,
                status: response.status,
                statusText: getStatusText(response.status),
                headers: new Headers(response.headers),
                url: response.url,
                
                // Response body methods
                json: async () => {
                    if (typeof response.data === 'string') {
                        return JSON.parse(response.data);
                    }
                    return response.data;
                },
                
                text: async () => {
                    if (typeof response.data === 'string') {
                        return response.data;
                    }
                    return JSON.stringify(response.data);
                },
                
                blob: async () => {
                    const text = await fetchResponse.text();
                    return new Blob([text], { type: 'application/octet-stream' });
                },
                
                arrayBuffer: async () => {
                    const text = await fetchResponse.text();
                    return new TextEncoder().encode(text).buffer;
                },
                
                clone: () => {
                    return createFetchResponse(response);
                }
            };

            console.log('✅ Fetch intercepted successfully:', response.status);
            return fetchResponse;

        } catch (error) {
            console.error('❌ Fetch interceptor error:', error);
            
            // Fallback to original fetch if available
            if (originalFetch) {
                console.log('🔄 Falling back to original fetch');
                return originalFetch(url, options);
            }
            
            throw error;
        }
    };

    // Helper function to get status text
    function getStatusText(status) {
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

    // Also intercept XMLHttpRequest for older code
    const originalXHR = window.XMLHttpRequest;
    window.XMLHttpRequest = function() {
        console.log('🔄 XMLHttpRequest intercepted - consider using fetch() instead');
        return new originalXHR();
    };

    console.log('✅ Capacitor Fetch Interceptor installed successfully');
} else {
    console.log('🌐 Running on web - no fetch interception needed');
}

// Export for manual use if needed
export { CapacitorHttp };