/**
 * Utility Helpers Module
 * Common utility functions used across the application
 */

/**
 * Debounce function calls
 */
function debounce(func, wait, immediate = false) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            timeout = null;
            if (!immediate) func(...args);
        };
        const callNow = immediate && !timeout;
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
        if (callNow) func(...args);
    };
}

/**
 * Throttle function calls
 */
function throttle(func, limit) {
    let inThrottle;
    return function(...args) {
        if (!inThrottle) {
            func.apply(this, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}

/**
 * Deep clone an object
 */
function deepClone(obj) {
    if (obj === null || typeof obj !== "object") return obj;
    if (obj instanceof Date) return new Date(obj.getTime());
    if (obj instanceof Array) return obj.map(item => deepClone(item));
    if (typeof obj === "object") {
        const clonedObj = {};
        for (const key in obj) {
            if (obj.hasOwnProperty(key)) {
                clonedObj[key] = deepClone(obj[key]);
            }
        }
        return clonedObj;
    }
}

/**
 * Check if object is empty
 */
function isEmpty(obj) {
    if (obj == null) return true;
    if (Array.isArray(obj) || typeof obj === 'string') return obj.length === 0;
    if (obj instanceof Map || obj instanceof Set) return obj.size === 0;
    if (typeof obj === 'object') return Object.keys(obj).length === 0;
    return false;
}

/**
 * Generate unique ID
 */
function generateId(prefix = 'id', length = 8) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = prefix + '_';
    for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}

/**
 * Format currency
 */
function formatCurrency(amount, currency = 'USD', locale = 'en-US') {
    return new Intl.NumberFormat(locale, {
        style: 'currency',
        currency: currency
    }).format(amount);
}

/**
 * Format number with commas
 */
function formatNumber(number, locale = 'en-US') {
    return new Intl.NumberFormat(locale).format(number);
}

/**
 * Format date
 */
function formatDate(date, options = {}) {
    const defaultOptions = {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    };
    
    const formatOptions = { ...defaultOptions, ...options };
    
    if (typeof date === 'string') {
        date = new Date(date);
    }
    
    return date.toLocaleDateString('en-US', formatOptions);
}

/**
 * Format relative time (e.g., "2 hours ago")
 */
function formatRelativeTime(date) {
    if (typeof date === 'string') {
        date = new Date(date);
    }
    
    const now = new Date();
    const diff = now - date;
    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    const weeks = Math.floor(days / 7);
    const months = Math.floor(days / 30);
    const years = Math.floor(days / 365);
    
    if (years > 0) return `${years} year${years > 1 ? 's' : ''} ago`;
    if (months > 0) return `${months} month${months > 1 ? 's' : ''} ago`;
    if (weeks > 0) return `${weeks} week${weeks > 1 ? 's' : ''} ago`;
    if (days > 0) return `${days} day${days > 1 ? 's' : ''} ago`;
    if (hours > 0) return `${hours} hour${hours > 1 ? 's' : ''} ago`;
    if (minutes > 0) return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
    if (seconds > 30) return `${seconds} second${seconds > 1 ? 's' : ''} ago`;
    return 'Just now';
}

/**
 * Format file size
 */
function formatFileSize(bytes) {
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    if (bytes === 0) return '0 Byte';
    const i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
    return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
}

/**
 * Capitalize first letter
 */
function capitalize(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
}

/**
 * Convert to title case
 */
function toTitleCase(str) {
    if (!str) return '';
    return str.replace(/\w\S*/g, (txt) => {
        return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
    });
}

/**
 * Convert to kebab case
 */
function toKebabCase(str) {
    if (!str) return '';
    return str
        .replace(/([a-z])([A-Z])/g, '$1-$2')
        .replace(/[\s_]+/g, '-')
        .toLowerCase();
}

/**
 * Convert to camel case
 */
function toCamelCase(str) {
    if (!str) return '';
    return str
        .replace(/(?:^\w|[A-Z]|\b\w)/g, (word, index) => {
            return index === 0 ? word.toLowerCase() : word.toUpperCase();
        })
        .replace(/[\s-_]+/g, '');
}

/**
 * Truncate text
 */
function truncateText(text, maxLength = 100, suffix = '...') {
    if (!text || text.length <= maxLength) return text;
    return text.substring(0, maxLength - suffix.length) + suffix;
}

/**
 * Escape HTML
 */
function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

/**
 * Strip HTML tags
 */
function stripHtml(html) {
    if (!html) return '';
    const div = document.createElement('div');
    div.innerHTML = html;
    return div.textContent || div.innerText || '';
}

/**
 * Parse URL parameters
 */
function parseUrlParams(url = window.location.href) {
    const params = {};
    const urlObj = new URL(url);
    
    for (const [key, value] of urlObj.searchParams) {
        params[key] = value;
    }
    
    return params;
}

/**
 * Build URL with parameters
 */
function buildUrl(baseUrl, params = {}) {
    const url = new URL(baseUrl);
    
    Object.entries(params).forEach(([key, value]) => {
        if (value !== null && value !== undefined && value !== '') {
            url.searchParams.set(key, value);
        }
    });
    
    return url.toString();
}

/**
 * Get nested object property safely
 */
function getNestedProperty(obj, path, defaultValue = undefined) {
    const keys = path.split('.');
    let current = obj;
    
    for (const key of keys) {
        if (current == null || typeof current !== 'object') {
            return defaultValue;
        }
        current = current[key];
    }
    
    return current !== undefined ? current : defaultValue;
}

/**
 * Set nested object property
 */
function setNestedProperty(obj, path, value) {
    const keys = path.split('.');
    const lastKey = keys.pop();
    let current = obj;
    
    for (const key of keys) {
        if (!(key in current) || typeof current[key] !== 'object') {
            current[key] = {};
        }
        current = current[key];
    }
    
    current[lastKey] = value;
}

/**
 * Merge objects deeply
 */
function mergeDeep(target, ...sources) {
    if (!sources.length) return target;
    const source = sources.shift();
    
    if (isObject(target) && isObject(source)) {
        for (const key in source) {
            if (isObject(source[key])) {
                if (!target[key]) Object.assign(target, { [key]: {} });
                mergeDeep(target[key], source[key]);
            } else {
                Object.assign(target, { [key]: source[key] });
            }
        }
    }
    
    return mergeDeep(target, ...sources);
}

/**
 * Check if value is an object
 */
function isObject(item) {
    return item && typeof item === 'object' && !Array.isArray(item);
}

/**
 * Array shuffle
 */
function shuffleArray(array) {
    const newArray = [...array];
    for (let i = newArray.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [newArray[i], newArray[j]] = [newArray[j], newArray[i]];
    }
    return newArray;
}

/**
 * Array unique values
 */
function uniqueArray(array, key = null) {
    if (key) {
        const seen = new Set();
        return array.filter(item => {
            const val = getNestedProperty(item, key);
            if (seen.has(val)) {
                return false;
            }
            seen.add(val);
            return true;
        });
    }
    return [...new Set(array)];
}

/**
 * Chunk array into smaller arrays
 */
function chunkArray(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
        chunks.push(array.slice(i, i + size));
    }
    return chunks;
}

/**
 * Get random item from array
 */
function randomArrayItem(array) {
    return array[Math.floor(Math.random() * array.length)];
}

/**
 * Wait for specified time
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Retry function with exponential backoff
 */
async function retry(fn, options = {}) {
    const {
        retries = 3,
        delay = 1000,
        backoff = 2,
        maxDelay = 10000
    } = options;
    
    let lastError;
    let currentDelay = delay;
    
    for (let i = 0; i <= retries; i++) {
        try {
            return await fn();
        } catch (error) {
            lastError = error;
            
            if (i === retries) {
                throw lastError;
            }
            
            await sleep(currentDelay);
            currentDelay = Math.min(currentDelay * backoff, maxDelay);
        }
    }
}

/**
 * Local storage helpers with error handling
 */
const storage = {
    set(key, value) {
        try {
            // localStorage removed - using Supabase);
            return true;
        } catch (error) {
            console.error('Failed to save to localStorage:', error);
            return false;
        }
    },
    
    get(key, defaultValue = null) {
        try {
            const item = null;
            return item ? JSON.parse(item) : defaultValue;
        } catch (error) {
            console.error('Failed to read from localStorage:', error);
            return defaultValue;
        }
    },
    
    remove(key) {
        try {
            // localStorage removed
            return true;
        } catch (error) {
            console.error('Failed to remove from localStorage:', error);
            return false;
        }
    },
    
    clear() {
        try {
            // localStorage removed
            return true;
        } catch (error) {
            console.error('Failed to clear localStorage:', error);
            return false;
        }
    }
};

/**
 * Cookie helpers
 */
const cookies = {
    set(name, value, days = 7) {
        const expires = new Date();
        expires.setTime(expires.getTime() + (days * 24 * 60 * 60 * 1000));
        document.cookie = `${name}=${value};expires=${expires.toUTCString()};path=/`;
    },
    
    get(name) {
        const nameEQ = name + "=";
        const ca = document.cookie.split(';');
        for (let i = 0; i < ca.length; i++) {
            let c = ca[i];
            while (c.charAt(0) === ' ') c = c.substring(1, c.length);
            if (c.indexOf(nameEQ) === 0) return c.substring(nameEQ.length, c.length);
        }
        return null;
    },
    
    remove(name) {
        document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`;
    }
};

/**
 * Device detection
 */
const device = {
    isMobile() {
        return window.innerWidth <= 768;
    },
    
    isTablet() {
        return window.innerWidth > 768 && window.innerWidth <= 1024;
    },
    
    isDesktop() {
        return window.innerWidth > 1024;
    },
    
    isTouchDevice() {
        return 'ontouchstart' in window || navigator.maxTouchPoints > 0;
    },
    
    getUserAgent() {
        return navigator.userAgent.toLowerCase();
    },
    
    getBrowser() {
        const ua = this.getUserAgent();
        if (ua.includes('chrome')) return 'chrome';
        if (ua.includes('firefox')) return 'firefox';
        if (ua.includes('safari')) return 'safari';
        if (ua.includes('edge')) return 'edge';
        return 'unknown';
    }
};

/**
 * Performance monitoring
 */
const performance = {
    measure(name, fn) {
        const start = Date.now();
        const result = fn();
        const end = Date.now();
        console.log(`⏱️ ${name}: ${end - start}ms`);
        return result;
    },
    
    async measureAsync(name, fn) {
        const start = Date.now();
        const result = await fn();
        const end = Date.now();
        console.log(`⏱️ ${name}: ${end - start}ms`);
        return result;
    }
};

/**
 * Event emitter for custom events
 */
class EventEmitter {
    constructor() {
        this.events = {};
    }
    
    on(event, callback) {
        if (!this.events[event]) {
            this.events[event] = [];
        }
        this.events[event].push(callback);
    }
    
    off(event, callback) {
        if (!this.events[event]) return;
        this.events[event] = this.events[event].filter(cb => cb !== callback);
    }
    
    emit(event, ...args) {
        if (!this.events[event]) return;
        this.events[event].forEach(callback => callback(...args));
    }
    
    once(event, callback) {
        const onceCallback = (...args) => {
            callback(...args);
            this.off(event, onceCallback);
        };
        this.on(event, onceCallback);
    }
}

// Export all utilities
export {
    debounce,
    throttle,
    deepClone,
    isEmpty,
    generateId,
    formatCurrency,
    formatNumber,
    formatDate,
    formatRelativeTime,
    formatFileSize,
    capitalize,
    toTitleCase,
    toKebabCase,
    toCamelCase,
    truncateText,
    escapeHtml,
    stripHtml,
    parseUrlParams,
    buildUrl,
    getNestedProperty,
    setNestedProperty,
    mergeDeep,
    isObject,
    shuffleArray,
    uniqueArray,
    chunkArray,
    randomArrayItem,
    sleep,
    retry,
    storage,
    cookies,
    device,
    performance,
    EventEmitter
};

// Export to window for backward compatibility
window.Utils = {
    debounce,
    throttle,
    deepClone,
    isEmpty,
    generateId,
    formatCurrency,
    formatNumber,
    formatDate,
    formatRelativeTime,
    formatFileSize,
    capitalize,
    toTitleCase,
    toKebabCase,
    toCamelCase,
    truncateText,
    escapeHtml,
    stripHtml,
    parseUrlParams,
    buildUrl,
    getNestedProperty,
    setNestedProperty,
    mergeDeep,
    isObject,
    shuffleArray,
    uniqueArray,
    chunkArray,
    randomArrayItem,
    sleep,
    retry,
    storage,
    cookies,
    device,
    performance,
    EventEmitter
};