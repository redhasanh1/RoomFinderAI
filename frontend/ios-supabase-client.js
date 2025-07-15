/**
 * iOS-Compatible Supabase Client for RoomFinderAI
 * 
 * This module provides an iOS-compatible Supabase client that uses @capacitor/http
 * for all network requests to ensure reliability on iOS devices.
 */

import { Capacitor } from '@capacitor/core';
import { CapacitorHttp } from '@capacitor/http';
import { fetch } from './ios-universal-fetch.js';

class IOSSupabaseClient {
    constructor(supabaseUrl, supabaseKey) {
        this.supabaseUrl = supabaseUrl;
        this.supabaseKey = supabaseKey;
        this.isNative = Capacitor.isNativePlatform();
        this.debug = true;
        
        // Headers for all requests
        this.defaultHeaders = {
            'apikey': supabaseKey,
            'Authorization': `Bearer ${supabaseKey}`,
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        };
        
        if (this.debug) {
            console.log('🟢 iOS Supabase Client initialized for:', this.isNative ? 'iOS Native' : 'Web');
        }
    }

    /**
     * Create a query builder for a table
     */
    from(table) {
        return new IOSSupabaseQueryBuilder(this, table);
    }

    /**
     * Execute RPC (Remote Procedure Call)
     */
    async rpc(functionName, params = {}) {
        const url = `${this.supabaseUrl}/rpc/${functionName}`;
        
        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: this.defaultHeaders,
                body: JSON.stringify(params)
            });

            if (!response.ok) {
                throw new Error(`RPC ${functionName} failed: ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error(`❌ RPC ${functionName} error:`, error);
            throw error;
        }
    }

    /**
     * Auth namespace for authentication operations
     */
    get auth() {
        return new IOSSupabaseAuth(this);
    }

    /**
     * Storage namespace for file operations
     */
    get storage() {
        return new IOSSupabaseStorage(this);
    }

    /**
     * Realtime namespace for subscriptions
     */
    channel(topic) {
        return new IOSSupabaseChannel(this, topic);
    }

    /**
     * Generic request method
     */
    async _request(method, url, data = null, additionalHeaders = {}) {
        const headers = { ...this.defaultHeaders, ...additionalHeaders };
        
        try {
            const response = await fetch(url, {
                method,
                headers,
                body: data ? JSON.stringify(data) : undefined
            });

            if (!response.ok) {
                const errorData = await response.json().catch(() => ({}));
                throw new Error(`Request failed: ${response.status} - ${errorData.message || response.statusText}`);
            }

            return await response.json();
        } catch (error) {
            console.error('❌ Supabase request error:', error);
            throw error;
        }
    }
}

/**
 * Query Builder for Supabase tables
 */
class IOSSupabaseQueryBuilder {
    constructor(client, table) {
        this.client = client;
        this.table = table;
        this.url = `${client.supabaseUrl}/rest/v1/${table}`;
        this.queryParams = new URLSearchParams();
        this.selectFields = '*';
        this.headers = { ...client.defaultHeaders };
    }

    /**
     * Select specific fields
     */
    select(fields = '*') {
        this.selectFields = fields;
        this.queryParams.set('select', fields);
        return this;
    }

    /**
     * Filter by equality
     */
    eq(column, value) {
        this.queryParams.set(column, `eq.${value}`);
        return this;
    }

    /**
     * Filter by inequality
     */
    neq(column, value) {
        this.queryParams.set(column, `neq.${value}`);
        return this;
    }

    /**
     * Filter by greater than
     */
    gt(column, value) {
        this.queryParams.set(column, `gt.${value}`);
        return this;
    }

    /**
     * Filter by less than
     */
    lt(column, value) {
        this.queryParams.set(column, `lt.${value}`);
        return this;
    }

    /**
     * Filter by LIKE pattern
     */
    like(column, pattern) {
        this.queryParams.set(column, `like.${pattern}`);
        return this;
    }

    /**
     * Filter by IN values
     */
    in(column, values) {
        this.queryParams.set(column, `in.(${values.join(',')})`);
        return this;
    }

    /**
     * Order results
     */
    order(column, options = {}) {
        const ascending = options.ascending !== false;
        this.queryParams.set('order', `${column}.${ascending ? 'asc' : 'desc'}`);
        return this;
    }

    /**
     * Limit results
     */
    limit(count) {
        this.queryParams.set('limit', count);
        return this;
    }

    /**
     * Offset results
     */
    offset(count) {
        this.queryParams.set('offset', count);
        return this;
    }

    /**
     * Get single result
     */
    single() {
        this.headers['Accept'] = 'application/vnd.pgrst.object+json';
        return this;
    }

    /**
     * Execute SELECT query
     */
    async exec() {
        const url = `${this.url}?${this.queryParams.toString()}`;
        
        try {
            const response = await fetch(url, {
                method: 'GET',
                headers: this.headers
            });

            if (!response.ok) {
                throw new Error(`Query failed: ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('❌ Supabase query error:', error);
            throw error;
        }
    }

    /**
     * Insert data
     */
    async insert(data) {
        const insertData = Array.isArray(data) ? data : [data];
        
        try {
            const response = await fetch(this.url, {
                method: 'POST',
                headers: {
                    ...this.headers,
                    'Prefer': 'return=representation'
                },
                body: JSON.stringify(insertData)
            });

            if (!response.ok) {
                throw new Error(`Insert failed: ${response.status}`);
            }

            const result = await response.json();
            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Supabase insert error:', error);
            return { data: null, error };
        }
    }

    /**
     * Update data
     */
    async update(data) {
        const url = `${this.url}?${this.queryParams.toString()}`;
        
        try {
            const response = await fetch(url, {
                method: 'PATCH',
                headers: {
                    ...this.headers,
                    'Prefer': 'return=representation'
                },
                body: JSON.stringify(data)
            });

            if (!response.ok) {
                throw new Error(`Update failed: ${response.status}`);
            }

            const result = await response.json();
            return { data: result, error: null };
        } catch (error) {
            console.error('❌ Supabase update error:', error);
            return { data: null, error };
        }
    }

    /**
     * Delete data
     */
    async delete() {
        const url = `${this.url}?${this.queryParams.toString()}`;
        
        try {
            const response = await fetch(url, {
                method: 'DELETE',
                headers: this.headers
            });

            if (!response.ok) {
                throw new Error(`Delete failed: ${response.status}`);
            }

            return { data: null, error: null };
        } catch (error) {
            console.error('❌ Supabase delete error:', error);
            return { data: null, error };
        }
    }
}

/**
 * Auth operations
 */
class IOSSupabaseAuth {
    constructor(client) {
        this.client = client;
    }

    /**
     * Sign up with email and password
     */
    async signUp(credentials) {
        const url = `${this.client.supabaseUrl}/auth/v1/signup`;
        
        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: this.client.defaultHeaders,
                body: JSON.stringify(credentials)
            });

            const result = await response.json();
            return { data: result, error: response.ok ? null : result };
        } catch (error) {
            console.error('❌ Supabase signup error:', error);
            return { data: null, error };
        }
    }

    /**
     * Sign in with email and password
     */
    async signInWithPassword(credentials) {
        const url = `${this.client.supabaseUrl}/auth/v1/token?grant_type=password`;
        
        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: this.client.defaultHeaders,
                body: JSON.stringify(credentials)
            });

            const result = await response.json();
            return { data: result, error: response.ok ? null : result };
        } catch (error) {
            console.error('❌ Supabase signin error:', error);
            return { data: null, error };
        }
    }

    /**
     * Sign out
     */
    async signOut() {
        const url = `${this.client.supabaseUrl}/auth/v1/logout`;
        
        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: this.client.defaultHeaders
            });

            return { error: response.ok ? null : await response.json() };
        } catch (error) {
            console.error('❌ Supabase signout error:', error);
            return { error };
        }
    }

    /**
     * Get current user
     */
    async getUser() {
        const url = `${this.client.supabaseUrl}/auth/v1/user`;
        
        try {
            const response = await fetch(url, {
                method: 'GET',
                headers: this.client.defaultHeaders
            });

            const result = await response.json();
            return { data: result, error: response.ok ? null : result };
        } catch (error) {
            console.error('❌ Supabase getUser error:', error);
            return { data: null, error };
        }
    }
}

/**
 * Storage operations
 */
class IOSSupabaseStorage {
    constructor(client) {
        this.client = client;
    }

    /**
     * Get storage bucket
     */
    from(bucket) {
        return new IOSSupabaseStorageBucket(this.client, bucket);
    }
}

/**
 * Storage bucket operations
 */
class IOSSupabaseStorageBucket {
    constructor(client, bucket) {
        this.client = client;
        this.bucket = bucket;
        this.baseUrl = `${client.supabaseUrl}/storage/v1/object/${bucket}`;
    }

    /**
     * Upload file
     */
    async upload(path, file, options = {}) {
        const url = `${this.baseUrl}/${path}`;
        
        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    ...this.client.defaultHeaders,
                    'Content-Type': file.type || 'application/octet-stream'
                },
                body: file
            });

            const result = await response.json();
            return { data: result, error: response.ok ? null : result };
        } catch (error) {
            console.error('❌ Supabase storage upload error:', error);
            return { data: null, error };
        }
    }

    /**
     * Get public URL
     */
    getPublicUrl(path) {
        return {
            data: {
                publicUrl: `${this.client.supabaseUrl}/storage/v1/object/public/${this.bucket}/${path}`
            }
        };
    }

    /**
     * Download file
     */
    async download(path) {
        const url = `${this.baseUrl}/${path}`;
        
        try {
            const response = await fetch(url, {
                method: 'GET',
                headers: this.client.defaultHeaders
            });

            const blob = await response.blob();
            return { data: blob, error: null };
        } catch (error) {
            console.error('❌ Supabase storage download error:', error);
            return { data: null, error };
        }
    }

    /**
     * Delete file
     */
    async remove(paths) {
        const url = `${this.baseUrl}`;
        
        try {
            const response = await fetch(url, {
                method: 'DELETE',
                headers: this.client.defaultHeaders,
                body: JSON.stringify({ prefixes: Array.isArray(paths) ? paths : [paths] })
            });

            const result = await response.json();
            return { data: result, error: response.ok ? null : result };
        } catch (error) {
            console.error('❌ Supabase storage remove error:', error);
            return { data: null, error };
        }
    }
}

/**
 * Realtime channel (simplified for iOS)
 */
class IOSSupabaseChannel {
    constructor(client, topic) {
        this.client = client;
        this.topic = topic;
        this.callbacks = {};
        this.isSubscribed = false;
    }

    /**
     * Subscribe to postgres changes
     */
    on(event, config, callback) {
        const key = `${event}_${config.table}`;
        this.callbacks[key] = callback;
        
        // For iOS, we'll use polling instead of WebSocket
        if (!this.isSubscribed) {
            this._startPolling();
        }
        
        return this;
    }

    /**
     * Subscribe to channel
     */
    subscribe() {
        console.log('📡 Subscribed to channel:', this.topic);
        return this;
    }

    /**
     * Unsubscribe from channel
     */
    unsubscribe() {
        this.isSubscribed = false;
        if (this.pollInterval) {
            clearInterval(this.pollInterval);
        }
        console.log('📡 Unsubscribed from channel:', this.topic);
    }

    /**
     * Start polling for changes (iOS fallback)
     */
    _startPolling() {
        this.isSubscribed = true;
        // This is a simplified polling mechanism
        // In a real implementation, you'd want more sophisticated change detection
        console.log('📡 Started polling for changes on:', this.topic);
    }
}

/**
 * Create iOS-compatible Supabase client
 */
export function createClient(supabaseUrl, supabaseKey) {
    return new IOSSupabaseClient(supabaseUrl, supabaseKey);
}

/**
 * Export default client creation function
 */
export default createClient;

console.log('✅ iOS Supabase Client module loaded successfully');