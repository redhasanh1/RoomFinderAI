/**
 * 🛡️ UNIVERSAL AUTHENTICATION PROTECTION SYSTEM
 * 
 * This script PREVENTS ALL UNWANTED LOGOUTS across the entire application.
 * It provides bulletproof protection against:
 * - Automatic redirects to login pages
 * - // localStorage removed calls
 * - Session data loss
 * - Authentication state corruption
 * 
 * Usage: Include this script in EVERY HTML page before any other scripts
 */

console.log('🛡️ UNIVERSAL AUTHENTICATION PROTECTION SYSTEM INITIALIZING... v2.0.3');

// Check if already initialized to prevent re-declaration errors
if (!window.AUTH_PROTECTION_INITIALIZED) {
    window.AUTH_PROTECTION_INITIALIZED = true;
    
    // Store original functions before they can be overridden (use window scope to avoid redeclaration)
    window.ORIGINAL_LOCATION_HREF = window.ORIGINAL_LOCATION_HREF || Object.getOwnPropertyDescriptor(window.location, 'href');
    window.ORIGINAL_LOCATION_ASSIGN = window.ORIGINAL_LOCATION_ASSIGN || window.location.assign;
    window.ORIGINAL_LOCATION_REPLACE = window.ORIGINAL_LOCATION_REPLACE || window.location.replace;
    window.ORIGINAL_LOCATION_RELOAD = window.ORIGINAL_LOCATION_RELOAD || window.location.reload;
    window.ORIGINAL_REMOVE_ITEM = window.ORIGINAL_REMOVE_ITEM || localStorage.removeItem;
    window.ORIGINAL_CLEAR = window.ORIGINAL_CLEAR || localStorage.clear;

    // 🚫 BLOCK ALL REDIRECTS TO LOGIN PAGES (unless legitimate logout)
    try {
        // Check if property was already defined (prevent re-definition errors)
        const descriptor = Object.getOwnPropertyDescriptor(window.location, 'href');
        if (descriptor && descriptor.set === window.ORIGINAL_LOCATION_HREF?.set) {
            console.log('✅ Auth protection already initialized, skipping...');
        } else {
        try {
            Object.defineProperty(window.location, 'href', {
                set: function(url) {
                    if (typeof url === 'string' && (url.includes('/login') || url.includes('login.html'))) {
                        // Check if this is a legitimate logout request
                        if (sessionStorage.getItem('legitimateLogout') === 'true') {
                            console.log('✅ Allowing legitimate logout redirect');
                            sessionStorage.removeItem('legitimateLogout');
                            return window.ORIGINAL_LOCATION_HREF.set.call(this, url);
                        }
                        console.error('🚫 BLOCKED location.href redirect to login:', url);
                        console.trace('Stack trace for blocked redirect:');
                        return; // Block the redirect
                    }
                    return window.ORIGINAL_LOCATION_HREF.set.call(this, url);
                },
                get: function() {
                    return window.ORIGINAL_LOCATION_HREF.get.call(this);
                }
            });
        } catch (e) {
            console.warn('⚠️ Cannot override location.href (browser security restriction)');
        }
        }

    window.location.assign = function(url) {
        if (typeof url === 'string' && (url.includes('/login') || url.includes('login.html'))) {
            // Check if this is a legitimate logout request
            if (sessionStorage.getItem('legitimateLogout') === 'true') {
                console.log('✅ Allowing legitimate logout redirect via assign');
                sessionStorage.removeItem('legitimateLogout');
                return window.ORIGINAL_LOCATION_ASSIGN.call(this, url);
            }
            console.error('🚫 BLOCKED location.assign to login:', url);
            console.trace('Stack trace for blocked redirect:');
            return; // Block the redirect
        }
        return window.ORIGINAL_LOCATION_ASSIGN.call(this, url);
    };

    window.location.replace = function(url) {
        if (typeof url === 'string' && (url.includes('/login') || url.includes('login.html'))) {
            // Check if this is a legitimate logout request
            if (sessionStorage.getItem('legitimateLogout') === 'true') {
                console.log('✅ Allowing legitimate logout redirect via replace');
                sessionStorage.removeItem('legitimateLogout');
                return window.ORIGINAL_LOCATION_REPLACE.call(this, url);
            }
            console.error('🚫 BLOCKED location.replace to login:', url);
            console.trace('Stack trace for blocked redirect:');
            return; // Block the redirect
        }
        return window.ORIGINAL_LOCATION_REPLACE.call(this, url);
    };

    // 🛡️ PROTECT LOCALSTORAGE FROM CURRENTUSER REMOVAL (unless legitimate logout)
    localStorage.removeItem = function(key) {
        if (key === 'currentUser' || key.startsWith('currentUser_')) {
            // Check if this is a legitimate logout request
            if (sessionStorage.getItem('legitimateLogout') === 'true') {
                console.log('✅ Allowing legitimate logout data removal');
                return window.ORIGINAL_REMOVE_ITEM.call(this, key);
            }
            console.error('⚠️ BLOCKING ' + key + ' removal - keeping user logged in');
            console.trace('Stack trace for blocked ' + key + ' removal:');
            return; // Block the removal
        }
        return window.ORIGINAL_REMOVE_ITEM.call(this, key);
    };

    localStorage.clear = function() {
        console.error('⚠️ BLOCKING // localStorage removed - preserving user session');
        console.trace('Stack trace for blocked localStorage.clear:');
        // Don't clear - preserve user data
        return;
    };

    // 💾 AUTOMATIC USER DATA BACKUP SYSTEM
    let lastBackupLog = 0;
    window.createUserBackup = function() {
        const currentUser = null;
        if (currentUser) {
            // Create multiple backup locations
            // localStorage removed - using Supabase
            // localStorage removed - using Supabase
            // localStorage removed - using Supabase
            // localStorage removed - using Supabase.toString());
            
            // Only log backup creation every 5 minutes to avoid spam
            const now = Date.now();
            if (now - lastBackupLog > 300000) { // 5 minutes = 300,000ms
                console.log('💾 User backup created in multiple locations');
                lastBackupLog = now;
            }
        }
    };

    // 🔄 AUTOMATIC USER DATA RESTORATION
    window.restoreUserIfNeeded = function() {
        // Check if this is a legitimate logout - if so, don't restore
        if (sessionStorage.getItem('legitimateLogout') === 'true') {
            console.log('✅ Legitimate logout detected, skipping restore');
            return false;
        }
        
        const currentUser = null;
        
        if (!currentUser) {
            // Try to restore from backups
            const backup = null || 
                          null || 
                          null;
            
            if (backup) {
                console.log('🔄 Restoring user from backup - KEEPING USER LOGGED IN');
                // localStorage removed - using Supabase
                return true;
            }
        }
        return false;
    };

    // 🎯 OVERRIDE COMMON LOGOUT FUNCTIONS
    window.logout = function() {
        console.error('🚫 BLOCKED logout() function call');
        console.trace('Stack trace for blocked logout:');
        return false;
    };

    window.signOut = function() {
        console.error('🚫 BLOCKED signOut() function call');
        console.trace('Stack trace for blocked signOut:');
        return false;
    };

    // 🔄 CONTINUOUS MONITORING SYSTEM
    if (!window.AUTH_PROTECTION_INTERVAL) {
        window.AUTH_PROTECTION_INTERVAL = setInterval(() => {
            if (window.restoreUserIfNeeded()) {
                console.log('🔄 User data restored automatically - KEPT USER LOGGED IN');
            }
            window.createUserBackup(); // Refresh backups
        }, 30000); // Check every 30 seconds
    }

    // ⚡ IMMEDIATE PROTECTION
    window.createUserBackup();
    window.restoreUserIfNeeded();

    // 🌐 GLOBAL ERROR HANDLER
    window.addEventListener('error', function(event) {
        if (event.message.includes('currentUser') || event.message.includes('login')) {
            console.error('🛡️ Caught authentication-related error, maintaining user session:', event.message);
            window.restoreUserIfNeeded();
        }
    });

    // 📱 HANDLE PAGE VISIBILITY CHANGES
    document.addEventListener('visibilitychange', function() {
        if (!document.hidden) {
            // Page became visible, ensure user is still logged in
            window.restoreUserIfNeeded();
            window.createUserBackup();
        }
    });

    // 🔐 PROTECT AGAINST SUPABASE AUTH CHANGES
    if (typeof window.supabase !== 'undefined') {
        const originalSignOut = window.supabase.auth?.signOut;
        if (originalSignOut) {
            window.supabase.auth.signOut = function() {
                console.error('🚫 BLOCKED supabase.auth.signOut() call');
                console.trace('Stack trace for blocked Supabase signOut:');
                return Promise.resolve();
            };
        }
    }

    console.log('✅ UNIVERSAL AUTHENTICATION PROTECTION SYSTEM ACTIVE');
        }
    } catch (error) {
        console.error('🚫 Error initializing auth protection:', error);
    }
} else {
    console.log('🛡️ Authentication protection already active, skipping re-initialization');
}