/**
 * Authentication Protection Module
 * Emergency protection system to prevent unwanted redirects and data loss
 */

class AuthProtection {
    constructor() {
        this.isInitialized = false;
        this.originalFunctions = {};
        this.backupInterval = null;

        this.init();
    }

    init() {
        if (this.isInitialized) return;

        console.log('🛡️ Initializing Authentication Protection System...');

        this.storeOriginalFunctions();
        this.setupRedirectProtection();
        this.setupLocalStorageProtection();
        this.setupUserDataBackup();

        this.isInitialized = true;
        console.log('✅ Authentication Protection System Active');
    }

    /**
     * Store original functions to prevent blocking
     */
    storeOriginalFunctions() {
        this.originalFunctions = {
            locationHref: Object.getOwnPropertyDescriptor(window.location, 'href'),
            locationAssign: window.location.assign,
            locationReplace: window.location.replace,
            locationReload: window.location.reload,
            removeItem: localStorage.removeItem
        };
    }

    /**
     * Setup protection against redirects to login pages
     */
    setupRedirectProtection() {
        const self = this;

        // Protect location.href
        try {
            Object.defineProperty(window.location, 'href', {
                set: function(url) {
                    if (self.shouldBlockRedirect(url)) {
                        console.error('🚫 BLOCKED location.href redirect to login:', url);
                        console.trace('Stack trace for blocked redirect:');
                        return;
                    }
                    return self.originalFunctions.locationHref.set.call(this, url);
                },
                get: function() {
                    return self.originalFunctions.locationHref.get.call(this);
                }
            });
        } catch (e) {
            console.log('⚠️ href property already defined, using alternative protection');
        }

        // Protect location.assign
        window.location.assign = function(url) {
            if (self.shouldBlockRedirect(url)) {
                console.error('🚫 BLOCKED location.assign to login:', url);
                console.trace('Stack trace for blocked redirect:');
                return;
            }
            return self.originalFunctions.locationAssign.call(this, url);
        };

        // Protect location.replace
        window.location.replace = function(url) {
            if (self.shouldBlockRedirect(url)) {
                console.error('🚫 BLOCKED location.replace to login:', url);
                console.trace('Stack trace for blocked redirect:');
                return;
            }
            return self.originalFunctions.locationReplace.call(this, url);
        };
    }

    /**
     * Setup protection for localStorage operations
     */
    setupLocalStorageProtection() {
        const self = this;

        localStorage.removeItem = function(key) {
            if (key === 'currentUser') {
                console.error('⚠️ BLOCKING currentUser removal for debugging');
                console.trace('Stack trace for blocked currentUser removal:');
                return;
            }
            return self.originalFunctions.removeItem.call(this, key);
        };
    }

    /**
     * Setup user data backup and restoration system
     */
    setupUserDataBackup() {
        // Create initial backup
        this.createUserBackup();

        // Start continuous monitoring
        this.backupInterval = setInterval(() => {
            if (this.restoreUserIfNeeded()) {
                console.log('🔄 User data restored automatically');
            }
            this.createUserBackup(); // Refresh backup
        }, 5000);
    }

    /**
     * Check if a redirect should be blocked
     */
    shouldBlockRedirect(url) {
        return typeof url === 'string' && url.includes('/login');
    }

    /**
     * Create backup of user data
     */
    createUserBackup() {
        const currentUser = localStorage.getItem('currentUser');
        if (currentUser) {
            localStorage.setItem('currentUser_backup', currentUser);
            localStorage.setItem('currentUser_backup_timestamp', Date.now().toString());
            console.log('💾 User backup created');
        }
    }

    /**
     * Restore user data from backup if needed
     */
    restoreUserIfNeeded() {
        const currentUser = localStorage.getItem('currentUser');
        const backup = localStorage.getItem('currentUser_backup');

        if (!currentUser && backup) {
            console.log('🔄 Restoring user from backup');
            localStorage.setItem('currentUser', backup);
            return true;
        }
        return false;
    }

    /**
     * Get current user from localStorage with fallback to backup
     */
    getCurrentUser() {
        let currentUser = localStorage.getItem('currentUser');

        if (!currentUser) {
            // Try to restore from backup
            if (this.restoreUserIfNeeded()) {
                currentUser = localStorage.getItem('currentUser');
            }
        }

        try {
            return currentUser ? JSON.parse(currentUser) : null;
        } catch (error) {
            console.error('Error parsing current user:', error);
            return null;
        }
    }

    /**
     * Set current user in localStorage with backup
     */
    setCurrentUser(user) {
        const userString = JSON.stringify(user);
        localStorage.setItem('currentUser', userString);
        this.createUserBackup();
    }

    /**
     * Clean up protection system
     */
    destroy() {
        if (this.backupInterval) {
            clearInterval(this.backupInterval);
            this.backupInterval = null;
        }

        // Restore original functions if needed
        if (this.originalFunctions.locationHref) {
            try {
                Object.defineProperty(window.location, 'href', this.originalFunctions.locationHref);
            } catch (e) {
                // Ignore errors
            }
        }

        window.location.assign = this.originalFunctions.locationAssign;
        window.location.replace = this.originalFunctions.locationReplace;
        localStorage.removeItem = this.originalFunctions.removeItem;

        this.isInitialized = false;
        console.log('🛡️ Authentication Protection System Deactivated');
    }
}

// Create global instance
window.authProtection = new AuthProtection();

export default window.authProtection;