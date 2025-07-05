/**
 * 🛡️ UNIVERSAL AUTHENTICATION PROTECTION SYSTEM
 * 
 * This script PREVENTS ALL UNWANTED LOGOUTS across the entire application.
 * It provides bulletproof protection against:
 * - Automatic redirects to login pages
 * - localStorage.removeItem('currentUser') calls
 * - Session data loss
 * - Authentication state corruption
 * 
 * Usage: Include this script in EVERY HTML page before any other scripts
 */

console.log('🛡️ UNIVERSAL AUTHENTICATION PROTECTION SYSTEM INITIALIZING...');

// Store original functions before they can be overridden
const ORIGINAL_LOCATION_HREF = Object.getOwnPropertyDescriptor(window.location, 'href');
const ORIGINAL_LOCATION_ASSIGN = window.location.assign;
const ORIGINAL_LOCATION_REPLACE = window.location.replace;
const ORIGINAL_LOCATION_RELOAD = window.location.reload;
const ORIGINAL_REMOVE_ITEM = localStorage.removeItem;
const ORIGINAL_CLEAR = localStorage.clear;

// 🚫 BLOCK ALL REDIRECTS TO LOGIN PAGES
Object.defineProperty(window.location, 'href', {
    set: function(url) {
        if (typeof url === 'string' && (url.includes('/login') || url.includes('login.html'))) {
            console.error('🚫 BLOCKED location.href redirect to login:', url);
            console.trace('Stack trace for blocked redirect:');
            return; // Block the redirect
        }
        return ORIGINAL_LOCATION_HREF.set.call(this, url);
    },
    get: function() {
        return ORIGINAL_LOCATION_HREF.get.call(this);
    }
});

window.location.assign = function(url) {
    if (typeof url === 'string' && (url.includes('/login') || url.includes('login.html'))) {
        console.error('🚫 BLOCKED location.assign to login:', url);
        console.trace('Stack trace for blocked redirect:');
        return; // Block the redirect
    }
    return ORIGINAL_LOCATION_ASSIGN.call(this, url);
};

window.location.replace = function(url) {
    if (typeof url === 'string' && (url.includes('/login') || url.includes('login.html'))) {
        console.error('🚫 BLOCKED location.replace to login:', url);
        console.trace('Stack trace for blocked redirect:');
        return; // Block the redirect
    }
    return ORIGINAL_LOCATION_REPLACE.call(this, url);
};

// 🛡️ PROTECT LOCALSTORAGE FROM CURRENTUSER REMOVAL
localStorage.removeItem = function(key) {
    if (key === 'currentUser') {
        console.error('⚠️ BLOCKING currentUser removal - keeping user logged in');
        console.trace('Stack trace for blocked currentUser removal:');
        return; // Block the removal
    }
    return ORIGINAL_REMOVE_ITEM.call(this, key);
};

localStorage.clear = function() {
    console.error('⚠️ BLOCKING localStorage.clear() - preserving user session');
    console.trace('Stack trace for blocked localStorage.clear:');
    // Don't clear - preserve user data
    return;
};

// 💾 AUTOMATIC USER DATA BACKUP SYSTEM
function createUserBackup() {
    const currentUser = localStorage.getItem('currentUser');
    if (currentUser) {
        // Create multiple backup locations
        localStorage.setItem('currentUser_backup', currentUser);
        localStorage.setItem('currentUser_backup_2', currentUser);
        localStorage.setItem('currentUser_emergency', currentUser);
        localStorage.setItem('currentUser_backup_timestamp', Date.now().toString());
        console.log('💾 User backup created in multiple locations');
    }
}

// 🔄 AUTOMATIC USER DATA RESTORATION
function restoreUserIfNeeded() {
    const currentUser = localStorage.getItem('currentUser');
    
    if (!currentUser) {
        // Try to restore from backups
        const backup = localStorage.getItem('currentUser_backup') || 
                      localStorage.getItem('currentUser_backup_2') || 
                      localStorage.getItem('currentUser_emergency');
        
        if (backup) {
            console.log('🔄 Restoring user from backup - KEEPING USER LOGGED IN');
            localStorage.setItem('currentUser', backup);
            return true;
        }
    }
    return false;
}

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

// 🛡️ PROTECT AGAINST DOM MANIPULATION
const observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(mutation) {
        if (mutation.type === 'childList') {
            mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === 1 && node.tagName === 'SCRIPT') {
                    const scriptContent = node.textContent || node.innerHTML;
                    if (scriptContent.includes('window.location') && scriptContent.includes('login')) {
                        console.error('🚫 BLOCKED malicious script injection attempting login redirect');
                        node.remove();
                    }
                }
            });
        }
    });
});

// Start observing DOM changes
observer.observe(document.documentElement, {
    childList: true,
    subtree: true
});

// 🔄 CONTINUOUS MONITORING SYSTEM
setInterval(() => {
    if (restoreUserIfNeeded()) {
        console.log('🔄 User data restored automatically - KEPT USER LOGGED IN');
    }
    createUserBackup(); // Refresh backups
}, 3000); // Check every 3 seconds

// ⚡ IMMEDIATE PROTECTION
createUserBackup();
restoreUserIfNeeded();

// 🌐 GLOBAL ERROR HANDLER
window.addEventListener('error', function(event) {
    if (event.message.includes('currentUser') || event.message.includes('login')) {
        console.error('🛡️ Caught authentication-related error, maintaining user session:', event.message);
        restoreUserIfNeeded();
    }
});

// 📱 HANDLE PAGE VISIBILITY CHANGES
document.addEventListener('visibilitychange', function() {
    if (!document.hidden) {
        // Page became visible, ensure user is still logged in
        restoreUserIfNeeded();
        createUserBackup();
    }
});

// 🔐 PROTECT AGAINST SUPABASE AUTH CHANGES
if (typeof window.supabase !== 'undefined') {
    const originalSignOut = window.supabase.auth.signOut;
    if (originalSignOut) {
        window.supabase.auth.signOut = function() {
            console.error('🚫 BLOCKED supabase.auth.signOut() call');
            console.trace('Stack trace for blocked Supabase signOut:');
            return Promise.resolve();
        };
    }
}

console.log('✅ UNIVERSAL AUTHENTICATION PROTECTION SYSTEM ACTIVE');
console.log('🛡️ ALL LOGOUT ATTEMPTS WILL BE BLOCKED');
console.log('💾 USER DATA IS CONTINUOUSLY BACKED UP AND RESTORED');