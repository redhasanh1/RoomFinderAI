/**
 * I18n Manager - Internationalization System for RoomPal
 * Supports 10 languages with RTL layout for Arabic and Hebrew
 *
 * Features:
 * - Auto-detect user language
 * - RTL/LTR layout switching
 * - Locale-aware formatting (numbers, dates, currency)
 * - Dynamic translation loading
 * - Fallback to English
 *
 * @version 2.0.0
 */

class I18nManager {
    constructor() {
        // Current locale settings
        this.currentLocale = 'en';
        this.direction = 'ltr';
        this.fallbackLocale = 'en';

        // Supported languages
        this.supportedLocales = [
            { code: 'en', name: 'English', nativeName: 'English', direction: 'ltr' },
            { code: 'es', name: 'Spanish', nativeName: 'Español', direction: 'ltr' },
            { code: 'fr', name: 'French', nativeName: 'Français', direction: 'ltr' },
            { code: 'de', name: 'German', nativeName: 'Deutsch', direction: 'ltr' },
            { code: 'zh', name: 'Chinese', nativeName: '中文', direction: 'ltr' },
            { code: 'ja', name: 'Japanese', nativeName: '日本語', direction: 'ltr' },
            { code: 'ko', name: 'Korean', nativeName: '한국어', direction: 'ltr' },
            { code: 'ar', name: 'Arabic', nativeName: 'العربية', direction: 'rtl' },
            { code: 'he', name: 'Hebrew', nativeName: 'עברית', direction: 'rtl' },
            { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', direction: 'ltr' }
        ];

        // RTL languages
        this.rtlLanguages = ['ar', 'he', 'fa', 'ur'];

        // Translation cache
        this.translations = {};
        this.loadingPromises = new Map();

        // Region-to-currency mapping
        this.currencyMap = {
            'en': 'USD',
            'es': 'EUR',
            'fr': 'EUR',
            'de': 'EUR',
            'zh': 'CNY',
            'ja': 'JPY',
            'ko': 'KRW',
            'ar': 'SAR',
            'he': 'ILS',
            'hi': 'INR'
        };

        // Region-to-timezone mapping
        this.timezoneMap = {
            'en': 'America/Los_Angeles',
            'es': 'Europe/Madrid',
            'fr': 'Europe/Paris',
            'de': 'Europe/Berlin',
            'zh': 'Asia/Shanghai',
            'ja': 'Asia/Tokyo',
            'ko': 'Asia/Seoul',
            'ar': 'Asia/Riyadh',
            'he': 'Asia/Jerusalem',
            'hi': 'Asia/Kolkata'
        };
    }

    /**
     * Initialize the i18n system
     * Detects user language, loads translations, applies direction
     */
    async init() {
        try {
            console.log('🌍 Initializing I18n Manager...');

            // Step 1: Detect user's preferred language
            this.currentLocale = await this.detectUserLanguage();
            console.log(`📍 Detected locale: ${this.currentLocale}`);

            // Step 2: Set direction (LTR or RTL)
            const localeInfo = this.supportedLocales.find(l => l.code === this.currentLocale);
            this.direction = localeInfo ? localeInfo.direction : 'ltr';

            // Step 3: Load translations for current language
            await this.loadTranslations(this.currentLocale);

            // Step 4: Apply direction to HTML
            this.applyDirection();

            // Step 5: Translate the page
            this.translatePage();

            // Step 6: Set up language switcher if it exists
            this.setupLanguageSwitcher();

            console.log(`✅ I18n initialized successfully: ${this.currentLocale} (${this.direction})`);

            return true;
        } catch (error) {
            console.error('❌ I18n initialization error:', error);
            // Fallback to English
            this.currentLocale = 'en';
            this.direction = 'ltr';
            return false;
        }
    }

    /**
     * Detect user's preferred language
     * Priority: 1) DB preference 2) localStorage 3) Browser 4) Fallback to English
     */
    async detectUserLanguage() {
        // 1. Check user preference from database (if logged in)
        const user = this.getCurrentUser();
        if (user && user.language) {
            if (this.isSupported(user.language)) {
                console.log(`🔐 Using user DB preference: ${user.language}`);
                return user.language;
            }
        }

        // 2. Check localStorage
        const storedLang = localStorage.getItem('roompal_language');
        if (storedLang && this.isSupported(storedLang)) {
            console.log(`💾 Using localStorage language: ${storedLang}`);
            return storedLang;
        }

        // 3. Check browser language
        const browserLang = navigator.language || navigator.userLanguage;
        const browserLangCode = browserLang.split('-')[0]; // 'en-US' -> 'en'
        if (this.isSupported(browserLangCode)) {
            console.log(`🌐 Using browser language: ${browserLangCode}`);
            return browserLangCode;
        }

        // 4. Fallback to English
        console.log(`🔤 Falling back to English`);
        return this.fallbackLocale;
    }

    /**
     * Check if a language code is supported
     */
    isSupported(langCode) {
        return this.supportedLocales.some(l => l.code === langCode);
    }

    /**
     * Load translations for a specific language
     * Tries to fetch from server, falls back to cached or English
     */
    async loadTranslations(langCode) {
        // Return cached translations if available
        if (this.translations[langCode]) {
            console.log(`📦 Using cached translations for: ${langCode}`);
            return this.translations[langCode];
        }

        // Prevent duplicate loading
        if (this.loadingPromises.has(langCode)) {
            return this.loadingPromises.get(langCode);
        }

        const loadPromise = (async () => {
            try {
                console.log(`⬇️ Loading translations for: ${langCode}`);

                // Try to fetch from server
                const response = await fetch(`/locales/${langCode}.json`);

                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}`);
                }

                const data = await response.json();
                this.translations[langCode] = data;
                console.log(`✅ Loaded ${Object.keys(data).length} translation keys for ${langCode}`);

                return data;
            } catch (error) {
                console.warn(`⚠️ Failed to load ${langCode} translations:`, error);

                // If not English, try to load English as fallback
                if (langCode !== this.fallbackLocale && !this.translations[this.fallbackLocale]) {
                    console.log(`🔄 Loading fallback language: ${this.fallbackLocale}`);
                    await this.loadTranslations(this.fallbackLocale);
                }

                return this.translations[this.fallbackLocale] || {};
            } finally {
                this.loadingPromises.delete(langCode);
            }
        })();

        this.loadingPromises.set(langCode, loadPromise);
        return loadPromise;
    }

    /**
     * Translate a string by key
     * Supports parameter replacement: t('hello.name', { name: 'John' })
     */
    t(key, params = {}) {
        // Get translation from current language
        let translation = this.getNestedValue(this.translations[this.currentLocale], key);

        // Fallback to English if not found
        if (!translation && this.currentLocale !== this.fallbackLocale) {
            translation = this.getNestedValue(this.translations[this.fallbackLocale], key);
        }

        // Fallback to key if still not found
        if (!translation) {
            console.warn(`⚠️ Missing translation: ${key}`);
            return key;
        }

        // Replace parameters
        Object.keys(params).forEach(param => {
            const placeholder = new RegExp(`\\{${param}\\}`, 'g');
            translation = translation.replace(placeholder, params[param]);
        });

        return translation;
    }

    /**
     * Get nested value from object by dot notation
     * Example: getNestedValue(obj, 'common.welcome') -> obj.common.welcome
     */
    getNestedValue(obj, path) {
        return path.split('.').reduce((current, key) => current?.[key], obj);
    }

    /**
     * Apply language direction to HTML document
     */
    applyDirection() {
        document.documentElement.setAttribute('dir', this.direction);
        document.documentElement.setAttribute('lang', this.currentLocale);
        document.body.classList.toggle('rtl', this.direction === 'rtl');
        document.body.classList.toggle('ltr', this.direction === 'ltr');

        console.log(`➡️ Applied direction: ${this.direction}`);
    }

    /**
     * Translate all elements on the page with data-i18n attribute
     * Usage: <h1 data-i18n="roompal.title">Will be translated</h1>
     */
    translatePage() {
        const elements = document.querySelectorAll('[data-i18n]');
        console.log(`🔄 Translating ${elements.length} elements...`);

        elements.forEach(element => {
            const key = element.getAttribute('data-i18n');
            const translation = this.t(key);

            // Check if element has data-i18n-html (allows HTML in translation)
            if (element.hasAttribute('data-i18n-html')) {
                element.innerHTML = translation;
            } else {
                element.textContent = translation;
            }
        });

        // Translate placeholder attributes
        document.querySelectorAll('[data-i18n-placeholder]').forEach(element => {
            const key = element.getAttribute('data-i18n-placeholder');
            element.placeholder = this.t(key);
        });

        // Translate aria-label attributes
        document.querySelectorAll('[data-i18n-aria]').forEach(element => {
            const key = element.getAttribute('data-i18n-aria');
            element.setAttribute('aria-label', this.t(key));
        });

        // Translate title attributes
        document.querySelectorAll('[data-i18n-title]').forEach(element => {
            const key = element.getAttribute('data-i18n-title');
            element.setAttribute('title', this.t(key));
        });
    }

    /**
     * Switch to a different language
     */
    async switchLanguage(langCode) {
        if (!this.isSupported(langCode)) {
            console.error(`❌ Unsupported language: ${langCode}`);
            return false;
        }

        if (langCode === this.currentLocale) {
            console.log(`ℹ️ Already using language: ${langCode}`);
            return true;
        }

        console.log(`🔄 Switching language from ${this.currentLocale} to ${langCode}`);

        // Update current locale
        this.currentLocale = langCode;

        // Update direction
        const localeInfo = this.supportedLocales.find(l => l.code === langCode);
        this.direction = localeInfo ? localeInfo.direction : 'ltr';

        // Load translations if not cached
        await this.loadTranslations(langCode);

        // Apply changes
        this.applyDirection();
        this.translatePage();

        // Save preference
        localStorage.setItem('roompal_language', langCode);
        await this.saveUserLanguagePreference(langCode);

        // Dispatch event for other components
        window.dispatchEvent(new CustomEvent('language-changed', {
            detail: { language: langCode, direction: this.direction }
        }));

        console.log(`✅ Language switched to: ${langCode}`);
        return true;
    }

    /**
     * Set up language switcher dropdown
     */
    setupLanguageSwitcher() {
        const switcher = document.getElementById('language-switcher');
        if (!switcher) return;

        // Populate language options
        switcher.innerHTML = this.supportedLocales.map(locale => `
            <option value="${locale.code}" ${locale.code === this.currentLocale ? 'selected' : ''}>
                ${locale.nativeName} (${locale.name})
            </option>
        `).join('');

        // Handle language change
        switcher.addEventListener('change', async (e) => {
            await this.switchLanguage(e.target.value);
        });
    }

    /**
     * Format numbers according to locale
     */
    formatNumber(number, options = {}) {
        return new Intl.NumberFormat(this.currentLocale, options).format(number);
    }

    /**
     * Format currency according to locale
     */
    formatCurrency(amount, currency = null) {
        const currencyCode = currency || this.currencyMap[this.currentLocale] || 'USD';

        return new Intl.NumberFormat(this.currentLocale, {
            style: 'currency',
            currency: currencyCode,
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(amount);
    }

    /**
     * Format date according to locale
     */
    formatDate(date, formatStyle = 'short') {
        const styles = {
            'short': { dateStyle: 'short' },
            'medium': { dateStyle: 'medium' },
            'long': { dateStyle: 'long' },
            'full': { dateStyle: 'full' }
        };

        return new Intl.DateTimeFormat(this.currentLocale,
            styles[formatStyle] || styles.short
        ).format(new Date(date));
    }

    /**
     * Format relative time (e.g., "3 days ago", "in 2 hours")
     */
    formatRelativeTime(date) {
        const now = new Date();
        const then = new Date(date);
        const diffMs = then - now;
        const diffSec = Math.floor(diffMs / 1000);
        const diffMin = Math.floor(diffSec / 60);
        const diffHour = Math.floor(diffMin / 60);
        const diffDay = Math.floor(diffHour / 24);

        const rtf = new Intl.RelativeTimeFormat(this.currentLocale, { numeric: 'auto' });

        if (Math.abs(diffDay) >= 1) {
            return rtf.format(diffDay, 'day');
        } else if (Math.abs(diffHour) >= 1) {
            return rtf.format(diffHour, 'hour');
        } else if (Math.abs(diffMin) >= 1) {
            return rtf.format(diffMin, 'minute');
        } else {
            return rtf.format(diffSec, 'second');
        }
    }

    /**
     * Get current user from localStorage or session
     */
    getCurrentUser() {
        try {
            const userStr = localStorage.getItem('currentUser');
            return userStr ? JSON.parse(userStr) : null;
        } catch (error) {
            console.error('Error getting current user:', error);
            return null;
        }
    }

    /**
     * Save user's language preference to database
     */
    async saveUserLanguagePreference(langCode) {
        const user = this.getCurrentUser();
        if (!user || !user.userId) return;

        try {
            // This would integrate with your Supabase API
            // For now, just log
            console.log(`💾 Would save language preference to DB: ${langCode}`);

            // Example API call (uncomment when backend is ready):
            /*
            await fetch('/api/user-preferences', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    userId: user.userId,
                    language: langCode,
                    direction: this.direction,
                    timezone: this.timezoneMap[langCode],
                    currency: this.currencyMap[langCode]
                })
            });
            */
        } catch (error) {
            console.error('Error saving language preference:', error);
        }
    }

    /**
     * Get language name by code
     */
    getLanguageName(code) {
        const locale = this.supportedLocales.find(l => l.code === code);
        return locale ? locale.nativeName : code;
    }

    /**
     * Get all supported languages
     */
    getSupportedLanguages() {
        return this.supportedLocales;
    }

    /**
     * Check if current language is RTL
     */
    isRTL() {
        return this.direction === 'rtl';
    }

    /**
     * Get currency for current locale
     */
    getCurrency() {
        return this.currencyMap[this.currentLocale] || 'USD';
    }

    /**
     * Get timezone for current locale
     */
    getTimezone() {
        return this.timezoneMap[this.currentLocale] || 'America/Los_Angeles';
    }
}

// Create global instance
window.i18n = new I18nManager();

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.i18n.init();
    });
} else {
    // DOM already loaded
    window.i18n.init();
}

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = I18nManager;
}
