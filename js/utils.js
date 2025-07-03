// Configuration module - must be defined before Utils
window.AppConfig = (function() {
    let SUPABASE_URL = null;
    let SUPABASE_ANON_KEY = null;
    let GOOGLE_API_KEY = null;
    let supabase = null;
    let isInitialized = false;

    // Initialize configuration with callback
    async function initialize(callback) {
        if (isInitialized && callback) {
            console.log('⚡ Config already initialized, running callback');
            callback();
            return;
        }

        console.log('🔧 Loading configuration...');
        
        try {
            const response = await fetch('/api/config');
            
            if (!response.ok) {
                throw new Error(`Config API returned ${response.status}`);
            }
            
            const config = await response.json();
            
            SUPABASE_URL = config.SUPABASE_URL;
            SUPABASE_ANON_KEY = config.SUPABASE_ANON_KEY;
            GOOGLE_API_KEY = config.GOOGLE_API_KEY;
            
            console.log('📡 Config loaded:', {
                hasSupabaseURL: !!SUPABASE_URL,
                hasSupabaseKey: !!SUPABASE_ANON_KEY,
                hasGoogleKey: !!GOOGLE_API_KEY
            });

            // Initialize Supabase client
            if (SUPABASE_URL && SUPABASE_ANON_KEY) {
                supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
                console.log('✅ Supabase client initialized');
                isInitialized = true;
                
                // Make supabase globally available for compatibility
                window.supabase = supabase;
                
                if (callback) callback();
            } else {
                throw new Error('Missing required configuration values');
            }
            
        } catch (error) {
            console.error('❌ Failed to load configuration:', error);
            throw error;
        }
    }

    // Get Supabase client
    function getSupabase() {
        return supabase;
    }

    // Get configuration values
    function getConfig() {
        return {
            SUPABASE_URL,
            SUPABASE_ANON_KEY,
            GOOGLE_API_KEY
        };
    }

    // Check if config is loaded
    function isLoaded() {
        return isInitialized && supabase !== null;
    }

    // Public API
    return {
        initialize,
        getSupabase,
        getConfig,
        isLoaded,
        
        // Direct access for compatibility
        get supabase() { return supabase; },
        get SUPABASE_URL() { return SUPABASE_URL; },
        get SUPABASE_ANON_KEY() { return SUPABASE_ANON_KEY; },
        get GOOGLE_API_KEY() { return GOOGLE_API_KEY; }
    };
})();

// Utility functions module
window.Utils = (function() {
    
    // Text processing utilities
    function autocorrectInput(input) {
        if (typeof input !== 'string' || !input) return input;
        
        // Check if typo.js is available
        if (!window.typo) {
            console.warn('Typo.js not available, skipping autocorrect');
            return input;
        }
        
        const words = input.split(' ');
        const correctedWords = words.map(word => {
            // Skip correction for:
            // 1. Numbers (including mixed alphanumeric like postal codes)
            if (/\d/.test(word)) {
                console.log(`Skipping autocorrect for number/code: ${word}`);
                return word;
            }
            
            // 2. Capitalized words (likely proper nouns like street names)
            if (/^[A-Z]/.test(word)) {
                console.log(`Skipping autocorrect for proper noun: ${word}`);
                return word;
            }
            
            // 3. Common address terms
            const addressTerms = ['street', 'road', 'avenue', 'drive', 'lane', 'court', 'place', 'way', 'blvd', 'ave', 'rd', 'dr', 'st', 'ln', 'ct', 'pl'];
            if (addressTerms.includes(word.toLowerCase())) {
                console.log(`Skipping autocorrect for address term: ${word}`);
                return word;
            }
            
            // 4. Words that are already correctly spelled
            if (window.typo.check(word)) {
                return word;
            }
            
            // 5. Only correct if word is clearly misspelled and suggestion is confident
            const suggestions = window.typo.suggest(word);
            if (suggestions.length > 0) {
                const suggestion = suggestions[0];
                // Only auto-correct if the suggestion is significantly different 
                // and the original word is clearly wrong (not just uncommon)
                if (word.length > 3 && suggestion.length > 2) {
                    console.log(`Autocorrect: ${word} -> ${suggestion}`);
                    return suggestion;
                }
            }
            
            console.log(`No autocorrect applied to: ${word}`);
            return word;
        });
        
        return correctedWords.join(' ');
    }

    // Safe autocorrect for addresses - only basic cleanup
    function cleanAddressInput(input) {
        if (typeof input !== 'string') return '';
        return input.trim()
            .replace(/\s+/g, ' ')  // Multiple spaces to single
            .replace(/[^\w\s\-.,#]/g, ''); // Remove special chars except basic ones
    }

    // Basic input sanitization
    function sanitizeInput(input) {
        if (typeof input !== 'string') return '';
        return input.replace(/[^a-zA-Z0-9\s,.-]/g, '').trim();
    }

    // File utilities
    function formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    function isImage(file) {
        if (!file) return false;
        
        // Check MIME type
        if (file.type && file.type.startsWith('image/')) {
            return true;
        }
        
        // Check file extension as fallback
        if (file.name) {
            const ext = file.name.split('.').pop().toLowerCase();
            return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(ext);
        }
        
        return false;
    }

    // Notification system
    function showNotification(message, type = 'info', duration = 5000) {
        // Remove existing notification
        const existing = document.getElementById('app-notification');
        if (existing) {
            existing.remove();
        }

        const colors = {
            success: { bg: '#d1fae5', border: '#10b981', text: '#065f46' },
            warning: { bg: '#fef3c7', border: '#f59e0b', text: '#92400e' },
            error: { bg: '#fee2e2', border: '#ef4444', text: '#991b1b' },
            info: { bg: '#dbeafe', border: '#3b82f6', text: '#1e40af' }
        };

        const color = colors[type] || colors.info;

        const notification = document.createElement('div');
        notification.id = 'app-notification';
        notification.style.cssText = `
            position: fixed;
            top: 70px;
            right: 20px;
            background: ${color.bg};
            border: 1px solid ${color.border};
            color: ${color.text};
            padding: 12px 16px;
            border-radius: 8px;
            font-family: Arial, sans-serif;
            font-size: 14px;
            max-width: 350px;
            z-index: 9999;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            animation: slideInRight 0.3s ease-out;
        `;

        notification.innerHTML = `
            <div style="display: flex; align-items: center; justify-content: space-between;">
                <span>${message}</span>
                <button onclick="this.parentElement.parentElement.remove()" style="
                    background: none; 
                    border: none; 
                    color: ${color.text}; 
                    font-size: 18px; 
                    cursor: pointer;
                    margin-left: 10px;
                ">×</button>
            </div>
        `;

        document.body.appendChild(notification);

        // Auto-remove after duration
        if (duration > 0) {
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.remove();
                }
            }, duration);
        }
    }

    // Debounce utility
    function debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    // LocalStorage utilities
    function getFromStorage(key, defaultValue = null) {
        try {
            const item = localStorage.getItem(key);
            return item ? JSON.parse(item) : defaultValue;
        } catch (error) {
            console.error(`Error reading from localStorage key "${key}":`, error);
            return defaultValue;
        }
    }

    function setToStorage(key, value) {
        try {
            localStorage.setItem(key, JSON.stringify(value));
            return true;
        } catch (error) {
            console.error(`Error writing to localStorage key "${key}":`, error);
            return false;
        }
    }

    function removeFromStorage(key) {
        try {
            localStorage.removeItem(key);
            return true;
        } catch (error) {
            console.error(`Error removing from localStorage key "${key}":`, error);
            return false;
        }
    }

    // Error handling utilities
    function handleError(error, userMessage = 'An error occurred', showAlert = true) {
        console.error('Error:', error);
        
        if (showAlert && userMessage) {
            showNotification(userMessage, 'error');
        }
        
        return { success: false, error: error.message || error };
    }

    // Date utilities
    function formatTimestamp(timestamp) {
        if (!timestamp) return '';
        
        try {
            const date = new Date(timestamp);
            return date.toLocaleString();
        } catch (error) {
            console.error('Error formatting timestamp:', error);
            return timestamp;
        }
    }

    function formatRelativeTime(timestamp) {
        if (!timestamp) return '';
        
        try {
            const now = new Date();
            const date = new Date(timestamp);
            const diffMs = now - date;
            
            const diffMins = Math.floor(diffMs / (1000 * 60));
            const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
            const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
            
            if (diffMins < 1) return 'Just now';
            if (diffMins < 60) return `${diffMins}m ago`;
            if (diffHours < 24) return `${diffHours}h ago`;
            if (diffDays < 7) return `${diffDays}d ago`;
            
            return date.toLocaleDateString();
        } catch (error) {
            console.error('Error formatting relative time:', error);
            return timestamp;
        }
    }

    // Validation utilities
    function isValidEmail(email) {
        const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return re.test(email);
    }

    function isValidUrl(string) {
        try {
            new URL(string);
            return true;
        } catch (_) {
            return false;
        }
    }

    // DOM utilities
    function createElement(tag, attributes = {}, content = '') {
        const element = document.createElement(tag);
        
        Object.keys(attributes).forEach(key => {
            if (key === 'className') {
                element.className = attributes[key];
            } else if (key === 'innerHTML') {
                element.innerHTML = attributes[key];
            } else {
                element.setAttribute(key, attributes[key]);
            }
        });
        
        if (content) {
            element.textContent = content;
        }
        
        return element;
    }

    // Public API
    return {
        // Text processing
        autocorrectInput,
        cleanAddressInput,
        sanitizeInput,
        
        // File utilities
        formatFileSize,
        isImage,
        
        // Notifications
        showNotification,
        showError: (message) => showNotification(message, 'error'),
        showSuccess: (message) => showNotification(message, 'success'),
        showWarning: (message) => showNotification(message, 'warning'),
        showInfo: (message) => showNotification(message, 'info'),
        
        // Timing
        debounce,
        
        // Storage
        getFromStorage,
        setToStorage,
        removeFromStorage,
        
        // Error handling
        handleError,
        
        // Date utilities
        formatTimestamp,
        formatRelativeTime,
        
        // Validation
        isValidEmail,
        isValidUrl,
        
        // DOM utilities
        createElement
    };
})();