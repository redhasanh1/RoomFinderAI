/**
 * Helper Utilities Module
 * Provides utility functions, formatters, validators, and general helpers
 */

class UtilityHelpers {
    constructor() {
        this.isInitialized = false;
        this.debounceTimers = new Map();
        this.throttleTimers = new Map();
    }

    /**
     * Initialize utility helpers
     */
    init() {
        this.setupGlobalHelpers();

        this.isInitialized = true;
        console.log('✅ Utility Helpers initialized');
    }

    /**
     * Setup global helper functions
     */
    setupGlobalHelpers() {
        // Make utility functions available globally for backward compatibility
        window.formatFileSize = this.formatFileSize.bind(this);
        window.sanitizeInput = this.sanitizeInput.bind(this);
        window.cleanAddressInput = this.cleanAddressInput.bind(this);
        window.debounce = this.debounce.bind(this);
        window.throttle = this.throttle.bind(this);
        window.validateEmail = this.validateEmail.bind(this);
        window.formatCurrency = this.formatCurrency.bind(this);
        window.formatDate = this.formatDate.bind(this);
        window.generateId = this.generateId.bind(this);
        window.isEmpty = this.isEmpty.bind(this);
        window.copyToClipboard = this.copyToClipboard.bind(this);
    }

    // ==================== STRING UTILITIES ====================

    /**
     * Sanitize input by removing dangerous characters
     */
    sanitizeInput(input) {
        if (typeof input !== 'string') return '';
        return input.replace(/[^a-zA-Z0-9\s,.-]/g, '').trim();
    }

    /**
     * Clean address input - only basic cleanup
     */
    cleanAddressInput(input) {
        if (typeof input !== 'string') return '';
        return input.trim()
            .replace(/\s+/g, ' ')  // Multiple spaces to single
            .replace(/[^\w\s\-.,#]/g, ''); // Remove special chars except basic ones
    }

    /**
     * Escape HTML characters
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    /**
     * Capitalize first letter of each word
     */
    titleCase(str) {
        return str.replace(/\w\S*/g, (txt) =>
            txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()
        );
    }

    /**
     * Convert string to slug format
     */
    slugify(text) {
        return text
            .toString()
            .toLowerCase()
            .trim()
            .replace(/\s+/g, '-')
            .replace(/[^\w\-]+/g, '')
            .replace(/\-\-+/g, '-')
            .replace(/^-+/, '')
            .replace(/-+$/, '');
    }

    /**
     * Truncate text with ellipsis
     */
    truncate(text, maxLength = 100, suffix = '...') {
        if (!text || text.length <= maxLength) return text;
        return text.substring(0, maxLength).trim() + suffix;
    }

    // ==================== FORMATTING UTILITIES ====================

    /**
     * Format file size in human readable format
     */
    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    /**
     * Format currency with locale
     */
    formatCurrency(amount, currency = 'USD', locale = 'en-US') {
        return new Intl.NumberFormat(locale, {
            style: 'currency',
            currency: currency
        }).format(amount);
    }

    /**
     * Format date in various formats
     */
    formatDate(date, format = 'locale') {
        const d = new Date(date);

        switch (format) {
            case 'locale':
                return d.toLocaleDateString();
            case 'time':
                return d.toLocaleTimeString();
            case 'datetime':
                return d.toLocaleString();
            case 'iso':
                return d.toISOString();
            case 'relative':
                return this.getRelativeTime(d);
            default:
                return d.toLocaleDateString();
        }
    }

    /**
     * Get relative time (e.g., "2 hours ago")
     */
    getRelativeTime(date) {
        const now = new Date();
        const diffInSeconds = Math.floor((now - date) / 1000);

        const intervals = {
            year: 31536000,
            month: 2592000,
            week: 604800,
            day: 86400,
            hour: 3600,
            minute: 60
        };

        for (const [unit, seconds] of Object.entries(intervals)) {
            const interval = Math.floor(diffInSeconds / seconds);
            if (interval >= 1) {
                return `${interval} ${unit}${interval > 1 ? 's' : ''} ago`;
            }
        }

        return 'Just now';
    }

    /**
     * Format phone number
     */
    formatPhoneNumber(phone) {
        const cleaned = phone.replace(/\D/g, '');
        const match = cleaned.match(/^(\d{3})(\d{3})(\d{4})$/);
        if (match) {
            return `(${match[1]}) ${match[2]}-${match[3]}`;
        }
        return phone;
    }

    // ==================== VALIDATION UTILITIES ====================

    /**
     * Validate email address
     */
    validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    /**
     * Validate phone number
     */
    validatePhone(phone) {
        const phoneRegex = /^[\+]?[1-9]?\d{9,15}$/;
        return phoneRegex.test(phone.replace(/\s/g, ''));
    }

    /**
     * Validate URL
     */
    validateUrl(url) {
        try {
            new URL(url);
            return true;
        } catch {
            return false;
        }
    }

    /**
     * Validate postal code
     */
    validatePostalCode(code, country = 'US') {
        const patterns = {
            US: /^\d{5}(-\d{4})?$/,
            CA: /^[A-Za-z]\d[A-Za-z][ -]?\d[A-Za-z]\d$/,
            UK: /^[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$/i
        };

        const pattern = patterns[country.toUpperCase()];
        return pattern ? pattern.test(code) : true; // Default to true for unknown countries
    }

    // ==================== TYPE CHECKING UTILITIES ====================

    /**
     * Check if value is empty
     */
    isEmpty(value) {
        if (value == null) return true;
        if (typeof value === 'string') return value.trim().length === 0;
        if (Array.isArray(value)) return value.length === 0;
        if (typeof value === 'object') return Object.keys(value).length === 0;
        return false;
    }

    /**
     * Check if value is array
     */
    isArray(value) {
        return Array.isArray(value);
    }

    /**
     * Check if value is object
     */
    isObject(value) {
        return value !== null && typeof value === 'object' && !Array.isArray(value);
    }

    /**
     * Check if value is function
     */
    isFunction(value) {
        return typeof value === 'function';
    }

    /**
     * Check if value is number
     */
    isNumber(value) {
        return typeof value === 'number' && !isNaN(value);
    }

    // ==================== PERFORMANCE UTILITIES ====================

    /**
     * Debounce function execution
     */
    debounce(func, delay, immediate = false) {
        const key = func.toString();

        return (...args) => {
            const callNow = immediate && !this.debounceTimers.has(key);

            clearTimeout(this.debounceTimers.get(key));

            this.debounceTimers.set(key, setTimeout(() => {
                this.debounceTimers.delete(key);
                if (!immediate) func.apply(this, args);
            }, delay));

            if (callNow) func.apply(this, args);
        };
    }

    /**
     * Throttle function execution
     */
    throttle(func, limit) {
        const key = func.toString();

        return (...args) => {
            if (!this.throttleTimers.has(key)) {
                func.apply(this, args);
                this.throttleTimers.set(key, setTimeout(() => {
                    this.throttleTimers.delete(key);
                }, limit));
            }
        };
    }

    /**
     * Simple memoization
     */
    memoize(func) {
        const cache = new Map();
        return (...args) => {
            const key = JSON.stringify(args);
            if (cache.has(key)) {
                return cache.get(key);
            }
            const result = func.apply(this, args);
            cache.set(key, result);
            return result;
        };
    }

    // ==================== OBJECT UTILITIES ====================

    /**
     * Deep clone an object
     */
    deepClone(obj) {
        if (obj === null || typeof obj !== 'object') return obj;
        if (obj instanceof Date) return new Date(obj.getTime());
        if (obj instanceof Array) return obj.map(item => this.deepClone(item));
        if (typeof obj === 'object') {
            const cloned = {};
            Object.keys(obj).forEach(key => {
                cloned[key] = this.deepClone(obj[key]);
            });
            return cloned;
        }
    }

    /**
     * Merge objects deeply
     */
    deepMerge(target, ...sources) {
        if (!sources.length) return target;
        const source = sources.shift();

        if (this.isObject(target) && this.isObject(source)) {
            for (const key in source) {
                if (this.isObject(source[key])) {
                    if (!target[key]) Object.assign(target, { [key]: {} });
                    this.deepMerge(target[key], source[key]);
                } else {
                    Object.assign(target, { [key]: source[key] });
                }
            }
        }

        return this.deepMerge(target, ...sources);
    }

    /**
     * Get nested property safely
     */
    getNestedProperty(obj, path, defaultValue = undefined) {
        const keys = path.split('.');
        let current = obj;

        for (const key of keys) {
            if (current == null || !current.hasOwnProperty(key)) {
                return defaultValue;
            }
            current = current[key];
        }

        return current;
    }

    /**
     * Set nested property safely
     */
    setNestedProperty(obj, path, value) {
        const keys = path.split('.');
        const lastKey = keys.pop();
        let current = obj;

        for (const key of keys) {
            if (!current[key] || typeof current[key] !== 'object') {
                current[key] = {};
            }
            current = current[key];
        }

        current[lastKey] = value;
        return obj;
    }

    // ==================== UTILITY FUNCTIONS ====================

    /**
     * Generate random ID
     */
    generateId(prefix = '', length = 8) {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        let result = prefix;
        for (let i = 0; i < length; i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return result;
    }

    /**
     * Generate UUID v4
     */
    generateUUID() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            const r = Math.random() * 16 | 0;
            const v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    /**
     * Copy text to clipboard
     */
    async copyToClipboard(text) {
        try {
            if (navigator.clipboard && window.isSecureContext) {
                await navigator.clipboard.writeText(text);
                return true;
            } else {
                // Fallback for older browsers
                const textArea = document.createElement('textarea');
                textArea.value = text;
                textArea.style.position = 'fixed';
                textArea.style.left = '-999999px';
                textArea.style.top = '-999999px';
                document.body.appendChild(textArea);
                textArea.focus();
                textArea.select();
                const result = document.execCommand('copy');
                document.body.removeChild(textArea);
                return result;
            }
        } catch (error) {
            console.error('Failed to copy to clipboard:', error);
            return false;
        }
    }

    /**
     * Wait for specified time
     */
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * Retry function with exponential backoff
     */
    async retry(func, maxAttempts = 3, baseDelay = 1000) {
        for (let attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                return await func();
            } catch (error) {
                if (attempt === maxAttempts) throw error;

                const delay = baseDelay * Math.pow(2, attempt - 1);
                console.log(`Attempt ${attempt} failed, retrying in ${delay}ms...`);
                await this.sleep(delay);
            }
        }
    }

    /**
     * Get random element from array
     */
    randomChoice(array) {
        return array[Math.floor(Math.random() * array.length)];
    }

    /**
     * Shuffle array
     */
    shuffleArray(array) {
        const shuffled = [...array];
        for (let i = shuffled.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
        }
        return shuffled;
    }

    /**
     * Remove duplicates from array
     */
    uniqueArray(array, key = null) {
        if (key) {
            const seen = new Set();
            return array.filter(item => {
                const val = this.getNestedProperty(item, key);
                if (seen.has(val)) return false;
                seen.add(val);
                return true;
            });
        }
        return [...new Set(array)];
    }

    /**
     * Group array by key
     */
    groupBy(array, key) {
        return array.reduce((groups, item) => {
            const value = this.getNestedProperty(item, key);
            const groupKey = value || 'undefined';
            if (!groups[groupKey]) groups[groupKey] = [];
            groups[groupKey].push(item);
            return groups;
        }, {});
    }

    /**
     * Sort array by multiple criteria
     */
    sortBy(array, ...criteria) {
        return [...array].sort((a, b) => {
            for (const criterion of criteria) {
                let aVal, bVal, desc = false;

                if (typeof criterion === 'string') {
                    aVal = this.getNestedProperty(a, criterion);
                    bVal = this.getNestedProperty(b, criterion);
                } else if (typeof criterion === 'object') {
                    const { key, order } = criterion;
                    aVal = this.getNestedProperty(a, key);
                    bVal = this.getNestedProperty(b, key);
                    desc = order === 'desc';
                }

                if (aVal < bVal) return desc ? 1 : -1;
                if (aVal > bVal) return desc ? -1 : 1;
            }
            return 0;
        });
    }

    /**
     * Get query string parameters
     */
    getQueryParams(url = window.location.href) {
        const params = new URLSearchParams(new URL(url).search);
        const result = {};
        for (const [key, value] of params) {
            result[key] = value;
        }
        return result;
    }

    /**
     * Update URL without reloading page
     */
    updateURL(params, replace = false) {
        const url = new URL(window.location);
        Object.entries(params).forEach(([key, value]) => {
            if (value === null || value === undefined) {
                url.searchParams.delete(key);
            } else {
                url.searchParams.set(key, value);
            }
        });

        if (replace) {
            window.history.replaceState({}, '', url);
        } else {
            window.history.pushState({}, '', url);
        }
    }

    /**
     * Destroy utility helpers
     */
    destroy() {
        // Clear all timers
        this.debounceTimers.forEach(timer => clearTimeout(timer));
        this.throttleTimers.forEach(timer => clearTimeout(timer));

        this.debounceTimers.clear();
        this.throttleTimers.clear();

        this.isInitialized = false;
        console.log('🗑️ Utility Helpers destroyed');
    }
}

// Create global instance
window.utilityHelpers = new UtilityHelpers();

export default window.utilityHelpers;